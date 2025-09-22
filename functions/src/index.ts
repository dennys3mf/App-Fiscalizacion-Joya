import {onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
// Ensure Storage types are available when using admin.storage()
import "firebase-admin/storage";
import {PDFDocument, rgb, StandardFonts} from "pdf-lib";
import {onCall, HttpsError} from "firebase-functions/v2/https";

// ================== INICIO DEL ARREGLO DE HORA v3 ==================
// Usamos formatInTimeZone para formatear en la zona horaria de Lima
import {formatInTimeZone} from "date-fns-tz";
// =================== FIN DEL ARREGLO DE HORA v3 ===================
import type {Request, Response} from "express";

admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage().bucket();

// Colores corporativos
const rojoMuni = rgb(211 / 255, 47 / 255, 47 / 255);
const doradoMuni = rgb(251 / 255, 192 / 255, 45 / 255);
const textoGris = rgb(0.3, 0.3, 0.3);

// Tipos y utilidades compartidas
type AnyDate = FirebaseFirestore.Timestamp | Date | string | number | null | undefined;

interface Boleta {
  id: string;
  fecha?: AnyDate;
  multa?: number;
  conforme?: string; // "Sí" | "No" | "Parcialmente" | undefined
  inspectorId?: string;
  [k: string]: any;
}

interface UserDoc {
  id: string;
  uid?: string;
  rol?: string; // "gerente" | "inspector" | ...
  estado?: string; // "Activo" | "Inactivo" | ...
  [k: string]: any;
}

const toDateSafe = (v: AnyDate): Date | null => {
  try {
    if (!v) return null;
    // Firestore Timestamp
    if (typeof (v as any).toDate === "function") return (v as any).toDate();
    if (v instanceof Date) return isNaN(v.getTime()) ? null : v;
    if (typeof v === "string") {
      const d = new Date(v);
      return isNaN(d.getTime()) ? null : d;
    }
    if (typeof v === "number") {
      const d = new Date(v);
      return isNaN(d.getTime()) ? null : d;
    }
  } catch {}
  return null;
};

const toMillis = (v: AnyDate): number | null => {
  const d = toDateSafe(v);
  return d ? d.getTime() : null;
};

export const verificarBoleta = onRequest(
  {
    region: "southamerica-west1",
    memory: "512MiB",
  },
  async (request: Request, response: Response) => {
    const boletaId = request.query.id;

    if (!boletaId || typeof boletaId !== "string") {
      response.status(400).send("ID de boleta no proporcionado o inválido.");
      return;
    }

    try {
      const doc = await db.collection("boletas").doc(boletaId).get();
      if (!doc.exists) {
        response.status(404).send("Boleta no encontrada.");
        return;
      }
      const boletaData = doc.data() as FirebaseFirestore.DocumentData;

      // Descarga de assets con manejo de errores específico
      const [logoResult, firmaResult] = await Promise.allSettled([
        storage.file("logo_muni_joya.png").download(),
        storage.file("firmas/firma_gerente.png").download(),
      ]);

      if (logoResult.status === "rejected") {
        const code = (logoResult.reason && (logoResult.reason.code || logoResult.reason.statusCode)) || 500;
        response.status(code === 404 ? 404 : 500).send("No se pudo cargar el logo institucional.");
        return;
      }
      if (firmaResult.status === "rejected") {
        const code = (firmaResult.reason && (firmaResult.reason.code || firmaResult.reason.statusCode)) || 500;
        response.status(code === 404 ? 404 : 500).send("No se pudo cargar la firma del gerente.");
        return;
      }

      const logoBytes = logoResult.value[0];
      const firmaBytes = firmaResult.value[0];

      const pdfDoc = await PDFDocument.create();
      const page = pdfDoc.addPage();
      const {width, height} = page.getSize();
      const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
      const fontBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);

      const logoImage = await pdfDoc.embedPng(logoBytes);
      const firmaImage = await pdfDoc.embedPng(firmaBytes);

      const margin = 50;
      let y = height - 70;

      page.drawImage(logoImage, {
        x: margin,
        y: y - 50,
        width: 80,
        height: 80,
      });

      page.drawText("MUNICIPALIDAD DISTRITAL DE LA JOYA", {
        x: margin + 100,
        y: y,
        font: fontBold,
        size: 18,
        color: rojoMuni,
      });
      page.drawText("GERENCIA DE TRANSPORTE", {
        x: margin + 100,
        y: y - 20,
        font: font,
        size: 14,
        color: textoGris,
      });

      y -= 100;

      page.drawLine({
        start: {x: margin, y},
        end: {x: width - margin, y},
        thickness: 2,
        color: doradoMuni,
      });

      y -= 30;

      page.drawText("BOLETA DE FISCALIZACIÓN - VERIFICACIÓN", {
        x: width / 2 - 170,
        y,
        font: fontBold,
        size: 16,
        color: rojoMuni,
      });

      y -= 40;

      const drawRow = (label: string, value: string) => {
        page.drawText(label, {x: margin, y, font: fontBold, size: 11, color: textoGris});
        page.drawText(value, {x: margin + 150, y, font, size: 11});
        y -= 20;
      };

      // ================== INICIO DEL ARREGLO DE HORA (robusto) ==================
      const fechaUTC = toDateSafe(boletaData.fecha);
      const fechaFormateada = fechaUTC
        ? formatInTimeZone(fechaUTC, "America/Lima", "dd/MM/yyyy HH:mm:ss")
        : "Sin fecha";
      // =================== FIN DEL ARREGLO DE HORA (robusto) ===================

      drawRow("Fecha y Hora:", fechaFormateada);
      drawRow("Placa:", boletaData.placa);
      drawRow("Empresa:", boletaData.empresa);
      drawRow("Conductor:", boletaData.nombreConductor || "No registrado");
      drawRow("N° Licencia:", boletaData.numeroLicencia || "No registrada");
      drawRow("Inspector:", boletaData.inspectorNombre || "No registrado");
      drawRow("Cód. Fiscalizador:", boletaData.codigoFiscalizador || "No registrado");

      y -= 15;

      // Utilidad simple para envolver texto según el ancho
      const wrapText = (text: string, maxWidth: number, fontRef = font, size = 11): string[] => {
        if (!text) return [];
        const words = text.split(/\s+/);
        const lines: string[] = [];
        let line = "";
        for (const word of words) {
          const test = line ? `${line} ${word}` : word;
          const w = fontRef.widthOfTextAtSize(test, size);
          if (w <= maxWidth) {
            line = test;
          } else {
            if (line) lines.push(line);
            line = word;
          }
        }
        if (line) lines.push(line);
        return lines;
      };

      const drawSection = (title: string, content: string) => {
        page.drawText(title, {x: margin, y, font: fontBold, size: 12, color: rojoMuni});
        y -= 20;
        const maxW = width - margin * 2;
        const lines = wrapText(content || "", maxW, font, 11);
        const lineHeight = 14;
        for (const line of lines) {
          page.drawText(line, {x: margin, y, font, size: 11});
          y -= lineHeight;
        }
        y -= 20;
      };

      drawSection("Motivo de la Intervención:", boletaData.motivo);
      drawSection("Conformidad:", boletaData.conforme || "No especificado.");
      drawSection("Observaciones del Inspector:", boletaData.observaciones || "Ninguna.");

      const firmaY = 80;
      page.drawImage(firmaImage, {
        x: width / 2 - 180,
        y: firmaY - 45,
        width: 360,
        height: 180,
      });
      page.drawLine({
        start: {x: width / 2 - 100, y: firmaY},
        end: {x: width / 2 + 100, y: firmaY},
        thickness: 0.5,
        color: textoGris,
      });
      page.drawText("Gerente de Transportes", {
        x: width / 2 - 55,
        y: firmaY - 15,
        font,
        size: 10,
        color: textoGris,
      });

      const pdfBytes = await pdfDoc.save();
      const fileName = `boleta_verificada_${boletaId}.pdf`;
      response.setHeader("Content-Type", "application/pdf");
      response.setHeader(
        "Content-Disposition",
        `inline; filename="${fileName}"`,
      );
      response.send(Buffer.from(pdfBytes));
    } catch (error) {
      console.error("Error al generar el PDF:", error);
      response.status(500).send("Error interno al generar el PDF.");
    }
  },
);


export const crearInspector = onCall(
  {
    region: "southamerica-west1",
  },
  async (request) => {
    // 1. Verificación de seguridad: ¿Quién está llamando a esta función?
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "La función debe ser llamada por un usuario autenticado.",
      );
    }
    const callerUid = request.auth.uid;

    try {
      // 2. Verificamos el ROL del usuario que llama
      const callerDoc = await db.collection("users").doc(callerUid).get();
      if (!callerDoc.exists || callerDoc.data()?.rol !== "gerente") {
        throw new HttpsError(
          "permission-denied",
          "No tienes permiso para ejecutar esta acción.",
        );
      }

      // 3. Obtenemos los datos del nuevo inspector enviados desde la app
      const {
        nombreCompleto,
        email,
        password,
        codigoFiscalizador,
        telefono,
        estado,
      } = request.data;

      if (!nombreCompleto || !email || !password || !codigoFiscalizador) {
        throw new HttpsError(
          "invalid-argument",
          "Por favor, proporciona todos los campos requeridos.",
        );
      }

      // 4. Creamos el usuario en Firebase Authentication
      const userRecord = await admin.auth().createUser({
        email: email,
        password: password,
        displayName: nombreCompleto,
      });

      // 5. Creamos el perfil del usuario en Firestore
      await db.collection("users").doc(userRecord.uid).set({
        uid: userRecord.uid,
        nombreCompleto: nombreCompleto,
        email: email,
        codigoFiscalizador: codigoFiscalizador,
        rol: "inspector", // Asignamos el rol por defecto
        telefono: telefono,
        estado: estado,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // 6. Si todo sale bien, enviamos una respuesta de éxito
      return {
        status: "success",
        message: `Inspector ${nombreCompleto} creado exitosamente.`,
        uid: userRecord.uid,
      };
    } catch (error: any) {
      // Manejo de errores
      if (error instanceof HttpsError) {
        throw error; // Re-lanzamos errores de HttpsError
      }
      console.error("Error al crear inspector:", error);
      throw new HttpsError(
        "internal",
        "Ocurrió un error interno al crear el inspector.",
      );
    }
  },
);

// ... (después de la función crearInspector)

export const getDashboardData = onCall(
  { region: "southamerica-west1" },
  async (request) => {
    if (!request.auth || (await db.collection("users").doc(request.auth.uid).get()).data()?.rol !== "gerente") {
      throw new HttpsError("permission-denied", "Acceso denegado.");
    }

    try {
      // Fetch users normally
      const usersSnapshot = await db.collection("users").get();

      // Try to order boletas by fecha; if it fails due to mixed types, fallback without orderBy
      let boletasSnapshot: FirebaseFirestore.QuerySnapshot;
      try {
        boletasSnapshot = await db.collection("boletas").orderBy("fecha", "desc").get();
      } catch (e) {
        boletasSnapshot = await db.collection("boletas").get();
      }

      const boletas: Boleta[] = boletasSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...(doc.data() as FirebaseFirestore.DocumentData),
      })) as Boleta[];
      const users: UserDoc[] = usersSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...(doc.data() as FirebaseFirestore.DocumentData),
      })) as UserDoc[];

      // Calcular KPIs (normalizando valores)
      const norm = (v?: string) => (v || '').trim().toLowerCase();
      const totalMultas = boletas.reduce((sum, b) => sum + (b.multa || 0), 0);
      const totalConformes = boletas.filter((b) => {
        const n = norm(b.conforme as any);
        return n === 'sí' || n === 'si';
      }).length;
      const totalNoConformes = boletas.filter((b) => norm(b.conforme as any) === 'no').length;
      const totalParciales = boletas.filter((b) => norm(b.conforme as any).startsWith('parcial')).length;
      const multasConMonto = boletas.filter((b) => (b.multa || 0) > 0).length;

      const estados = boletas.reduce((acc, b) => {
        const e = norm((b as any).estado);
        if (e === 'activa' || e === 'activo') acc.activa++;
        else if (e === 'pagada' || e === 'pagado') acc.pagada++;
        else if (e === 'anulada' || e === 'anulado') acc.anulada++;
        return acc;
      }, { activa: 0, pagada: 0, anulada: 0 } as {activa: number; pagada: number; anulada: number});

      const promedioMulta = multasConMonto > 0 ? totalMultas / multasConMonto : 0;
      const multasActivas = estados.activa;
      const multasPagadas = estados.pagada;
      
      const inspectores = users
        .filter((u) => u.rol === "inspector")
        .map((inspector) => {
          const inspectorKey = inspector.uid || inspector.id;
          const susBoletas = boletas.filter((b) => b.inspectorId === inspectorKey);
          const ultima = susBoletas.length > 0 ? toMillis(susBoletas[0].fecha) : null;

          // Normalize conformity counts
          const norm = (v?: string) => (v || '').trim().toLowerCase();
          const conformes = susBoletas.filter((b) => {
            const n = norm(b.conforme as any);
            return n === 'sí' || n === 'si';
          }).length;
          const noConformes = susBoletas.filter((b) => norm(b.conforme as any) === 'no').length;

          // Only return JSON-safe subset of inspector fields
          return {
            id: inspector.id,
            uid: inspector.uid || inspector.id,
            nombreCompleto: (inspector as any).nombreCompleto || '',
            email: (inspector as any).email || '',
            codigoFiscalizador: (inspector as any).codigoFiscalizador || '',
            telefono: (inspector as any).telefono || '',
            estado: (inspector as any).estado || '',
            rol: (inspector as any).rol || '',
            createdAtMillis: toMillis((inspector as any).createdAt),
            boletas: susBoletas.length,
            conformes,
            noConformes,
            ultimaActividad: ultima,
          };
        });

      // Ensure boletasRecientes are JSON-safe and sorted by millis desc
      const sortedBoletas = [...boletas].sort((a, b) => (toMillis(b.fecha) || 0) - (toMillis(a.fecha) || 0));
      return {
        totalBoletas: boletas.length,
        totalConformes,
        totalNoConformes,
        totalParciales,
        totalMultas,
        multasConMonto,
        promedioMulta,
        estados,
        multasActivas,
        multasPagadas,
        inspectoresActivos: inspectores.filter((i) => i.estado === "Activo").length,
        totalInspectores: inspectores.length,
        boletasRecientes: sortedBoletas.slice(0, 5).map((b) => ({
          id: b.id,
          placa: (b as any).placa || '',
          empresa: (b as any).empresa || '',
          nombreConductor: (b as any).nombreConductor || (b as any).conductor || '',
          inspectorNombre: (b as any).inspectorNombre || '',
          estado: (b as any).estado || '',
          multa: b.multa || 0,
          fecha: toMillis(b.fecha),
        })),
        inspectores,
      };
    } catch (error) {
      console.error("Error al obtener datos del dashboard:", error);
      throw new HttpsError("internal", "No se pudieron cargar los datos del dashboard.");
    }
  },
);

// Lista de boletas con filtros simples para el panel web (evita leer Firestore desde el cliente)
export const listBoletas = onCall(
  { region: "southamerica-west1" },
  async (request) => {
    if (!request.auth || (await db.collection("users").doc(request.auth.uid).get()).data()?.rol !== "gerente") {
      throw new HttpsError("permission-denied", "Acceso denegado.");
    }

    try {
      const { limit = 200, withPhotos = false } = (request.data || {}) as { limit?: number; withPhotos?: boolean };
      const safeLimit = Math.max(1, Math.min(1000, Number(limit) || 200));

      // Intentar ordenar por 'fecha' si el campo es consistente; si falla, hacer fallback sin orderBy
      let snap: FirebaseFirestore.QuerySnapshot;
      try {
        const q = db.collection("boletas").orderBy("fecha", "desc").limit(safeLimit);
        snap = await q.get();
      } catch (e) {
        const q = db.collection("boletas").limit(safeLimit);
        snap = await q.get();
      }
      type Loose = { [k: string]: any };
      const rawItems: Loose[] = snap.docs.map((doc) => ({ id: doc.id, ...(doc.data() as FirebaseFirestore.DocumentData) }));

      // Sanitize each item to JSON-safe fields only
      const sanitized = rawItems.map((m) => {
        const placa = (m["placa"]) || "";
        const empresa = (m["empresa"]) || "";
        const conductor = m["conductor"] || m["nombreConductor"] || "";
        const numeroLicencia = (m["numeroLicencia"]) || "";
        const conforme = (m["conforme"]) || "";
        const estado = (m["estado"]) || "";
        const multaVal = typeof m["multa"] === 'number' ? m["multa"] : 0;
        const motivo = m["motivo"] || m["infraccion"] || "";
        const inspectorId = m["inspectorId"] || "";
        const inspectorNombre = m["inspectorNombre"] || "";
        const inspectorEmail = m["inspectorEmail"] || "";
        const codigoFiscalizador = m["codigoFiscalizador"] || "";
        const foto = m["fotoLicencia"] || m["urlFotoLicencia"] || "";
        const urlFoto = m["urlFotoLicencia"] || m["fotoLicencia"] || "";
        const descripciones = (typeof m["descripciones"] === 'string') ? m["descripciones"] : undefined;
        const observaciones = (typeof m["observaciones"] === 'string') ? m["observaciones"] : undefined;
        const fechaMillis = toMillis(m["fecha"]);

        return {
          id: m.id,
          placa,
          empresa,
          conductor,
          nombreConductor: conductor,
          numeroLicencia,
          conforme,
          estado,
          multa: multaVal,
          motivo,
          inspectorId,
          inspectorNombre,
          inspectorEmail,
          codigoFiscalizador,
          fotoLicencia: foto,
          urlFotoLicencia: urlFoto,
          descripciones,
          observaciones,
          fecha: fechaMillis,
        } as Loose;
      });

      const filtered = withPhotos
        ? sanitized.filter((m) => !!(m["fotoLicencia"] || m["urlFotoLicencia"]))
        : sanitized;

      const sorted = filtered.sort((a, b) => ((b["fecha"] || 0) as number) - ((a["fecha"] || 0) as number));

      return { items: sorted };
    } catch (error) {
      console.error("Error en listBoletas:", error);
      throw new HttpsError("internal", "No se pudieron listar las boletas.");
    }
  },
);

// HTTP variant with explicit CORS for web environments that face CORS issues with callable protocol
export const listBoletasHttp = onRequest(
  { region: "southamerica-west1" },
  async (req: Request, res: Response) => {
    // CORS headers
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    try {
      // Verify ID token from Authorization: Bearer <token>
      const authHeader = (req.headers["authorization"] || req.headers["Authorization"]) as string | undefined;
      const token = authHeader && authHeader.startsWith("Bearer ") ? authHeader.substring(7) : undefined;
      if (!token) {
        res.status(401).json({ error: "unauthenticated" });
        return;
      }
      const decoded = await admin.auth().verifyIdToken(token);
      const uid = decoded.uid;
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists || userDoc.data()?.rol !== "gerente") {
        res.status(403).json({ error: "permission-denied" });
        return;
      }

      const limitParam = Array.isArray(req.query.limit) ? req.query.limit[0] : req.query.limit;
  const withPhotosParam = Array.isArray(req.query.withPhotos) ? req.query.withPhotos[0] : req.query.withPhotos;
  const limit = Math.max(1, Math.min(1000, Number(limitParam) || 200));
  const withPhotos = (typeof withPhotosParam === 'string') ? (withPhotosParam === 'true') : false;

      // Fetch boletas with fallback order
      let snap: FirebaseFirestore.QuerySnapshot;
      try {
        snap = await db.collection("boletas").orderBy("fecha", "desc").limit(limit).get();
      } catch {
        snap = await db.collection("boletas").limit(limit).get();
      }

      type Loose = { [k: string]: any };
      const rawItems: Loose[] = snap.docs.map((doc) => ({ id: doc.id, ...(doc.data() as FirebaseFirestore.DocumentData) }));
      const sanitized = rawItems.map((m) => {
        const placa = m["placa"] || "";
        const empresa = m["empresa"] || "";
        const conductor = m["conductor"] || m["nombreConductor"] || "";
        const numeroLicencia = m["numeroLicencia"] || "";
        const conforme = m["conforme"] || "";
        const estado = m["estado"] || "";
        const multaVal = typeof m["multa"] === 'number' ? m["multa"] : 0;
        const motivo = m["motivo"] || m["infraccion"] || "";
        const inspectorId = m["inspectorId"] || "";
        const inspectorNombre = m["inspectorNombre"] || "";
        const inspectorEmail = m["inspectorEmail"] || "";
        const codigoFiscalizador = m["codigoFiscalizador"] || "";
        const foto = m["fotoLicencia"] || m["urlFotoLicencia"] || "";
        const urlFoto = m["urlFotoLicencia"] || m["fotoLicencia"] || "";
        const descripciones = typeof m["descripciones"] === 'string' ? m["descripciones"] : undefined;
        const observaciones = typeof m["observaciones"] === 'string' ? m["observaciones"] : undefined;
        const fechaMillis = toMillis(m["fecha"]);
        return {
          id: m.id,
          placa,
          empresa,
          conductor,
          nombreConductor: conductor,
          numeroLicencia,
          conforme,
          estado,
          multa: multaVal,
          motivo,
          inspectorId,
          inspectorNombre,
          inspectorEmail,
          codigoFiscalizador,
          fotoLicencia: foto,
          urlFotoLicencia: urlFoto,
          descripciones,
          observaciones,
          fecha: fechaMillis,
        } as Loose;
      });

      const filtered = withPhotos
        ? sanitized.filter((m) => !!(m["fotoLicencia"] || m["urlFotoLicencia"]))
        : sanitized;
      const sorted = filtered.sort((a, b) => ((b["fecha"] || 0) as number) - ((a["fecha"] || 0) as number));

      res.status(200).json({ items: sorted });
    } catch (error) {
      console.error("Error en listBoletasHttp:", error);
      res.status(500).json({ error: "internal" });
    }
  }
);

// HTTP variant for dashboard metrics with explicit CORS
export const getDashboardDataHttp = onRequest(
  { region: "southamerica-west1" },
  async (req: Request, res: Response) => {
    // CORS headers
    res.setHeader("Access-Control-Allow-Origin", "*");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    try {
      // Verify ID token
      const authHeader = (req.headers["authorization"] || req.headers["Authorization"]) as string | undefined;
      const token = authHeader && authHeader.startsWith("Bearer ") ? authHeader.substring(7) : undefined;
      if (!token) {
        res.status(401).json({ error: "unauthenticated" });
        return;
      }
      const decoded = await admin.auth().verifyIdToken(token);
      const uid = decoded.uid;
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists || userDoc.data()?.rol !== "gerente") {
        res.status(403).json({ error: "permission-denied" });
        return;
      }

      // Fetch users and boletas with fallback order
      const usersSnapshot = await db.collection("users").get();
      let boletasSnapshot: FirebaseFirestore.QuerySnapshot;
      try {
        boletasSnapshot = await db.collection("boletas").orderBy("fecha", "desc").get();
      } catch {
        boletasSnapshot = await db.collection("boletas").get();
      }

      const boletas: Boleta[] = boletasSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...(doc.data() as FirebaseFirestore.DocumentData),
      })) as Boleta[];
      const users: UserDoc[] = usersSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...(doc.data() as FirebaseFirestore.DocumentData),
      })) as UserDoc[];

      const norm = (v?: string) => (v || '').trim().toLowerCase();
      const totalMultas = boletas.reduce((sum, b) => sum + (b.multa || 0), 0);
      const totalConformes = boletas.filter((b) => {
        const n = norm(b.conforme as any);
        return n === 'sí' || n === 'si';
      }).length;
      const totalNoConformes = boletas.filter((b) => norm(b.conforme as any) === 'no').length;
      const totalParciales = boletas.filter((b) => norm(b.conforme as any).startsWith('parcial')).length;
      const multasConMonto = boletas.filter((b) => (b.multa || 0) > 0).length;
      const estados = boletas.reduce((acc, b) => {
        const e = norm((b as any).estado);
        if (e === 'activa' || e === 'activo') acc.activa++;
        else if (e === 'pagada' || e === 'pagado') acc.pagada++;
        else if (e === 'anulada' || e === 'anulado') acc.anulada++;
        return acc;
      }, { activa: 0, pagada: 0, anulada: 0 } as {activa: number; pagada: number; anulada: number});
      const promedioMulta = multasConMonto > 0 ? totalMultas / multasConMonto : 0;
      const multasActivas = estados.activa;
      const multasPagadas = estados.pagada;

      const inspectores = users
        .filter((u) => u.rol === "inspector")
        .map((inspector) => {
          const inspectorKey = inspector.uid || inspector.id;
          const susBoletas = boletas.filter((b) => b.inspectorId === inspectorKey);
          const ultima = susBoletas.length > 0 ? toMillis(susBoletas[0].fecha) : null;
          const conformes = susBoletas.filter((b) => {
            const n = norm(b.conforme as any);
            return n === 'sí' || n === 'si';
          }).length;
          const noConformes = susBoletas.filter((b) => norm(b.conforme as any) === 'no').length;
          return {
            id: inspector.id,
            uid: inspector.uid || inspector.id,
            nombreCompleto: (inspector as any).nombreCompleto || '',
            email: (inspector as any).email || '',
            codigoFiscalizador: (inspector as any).codigoFiscalizador || '',
            telefono: (inspector as any).telefono || '',
            estado: (inspector as any).estado || '',
            rol: (inspector as any).rol || '',
            createdAtMillis: toMillis((inspector as any).createdAt),
            boletas: susBoletas.length,
            conformes,
            noConformes,
            ultimaActividad: ultima,
          };
        });

      const sortedBoletas = [...boletas].sort((a, b) => (toMillis(b.fecha) || 0) - (toMillis(a.fecha) || 0));

      res.status(200).json({
        totalBoletas: boletas.length,
        totalConformes,
        totalNoConformes,
        totalParciales,
        totalMultas,
        multasConMonto,
        promedioMulta,
        estados,
        multasActivas,
        multasPagadas,
        inspectoresActivos: inspectores.filter((i) => i.estado === "Activo").length,
        totalInspectores: inspectores.length,
        boletasRecientes: sortedBoletas.slice(0, 5).map((b) => ({
          id: b.id,
          placa: (b as any).placa || '',
          empresa: (b as any).empresa || '',
          nombreConductor: (b as any).nombreConductor || (b as any).conductor || '',
          inspectorNombre: (b as any).inspectorNombre || '',
          estado: (b as any).estado || '',
          multa: b.multa || 0,
          fecha: toMillis(b.fecha),
        })),
        inspectores,
      });
    } catch (error) {
      console.error("Error en getDashboardDataHttp:", error);
      res.status(500).json({ error: "internal" });
    }
  }
);