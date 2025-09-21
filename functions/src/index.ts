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
      const [boletasSnapshot, usersSnapshot] = await Promise.all([
        db.collection("boletas").orderBy("fecha", "desc").get(),
        db.collection("users").get(),
      ]);

      const boletas: Boleta[] = boletasSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...(doc.data() as FirebaseFirestore.DocumentData),
      })) as Boleta[];
      const users: UserDoc[] = usersSnapshot.docs.map((doc) => ({
        id: doc.id,
        ...(doc.data() as FirebaseFirestore.DocumentData),
      })) as UserDoc[];

      // Calcular KPIs
      const totalMultas = boletas.reduce((sum, b) => sum + (b.multa || 0), 0);
      const totalConformes = boletas.filter((b) => b.conforme === "Sí").length;
      const totalNoConformes = boletas.filter((b) => b.conforme === "No").length;
      const totalParciales = boletas.filter((b) => b.conforme === "Parcialmente").length;
      
      const inspectores = users
        .filter((u) => u.rol === "inspector")
        .map((inspector) => {
          const inspectorKey = inspector.uid || inspector.id;
          const susBoletas = boletas.filter((b) => b.inspectorId === inspectorKey);
          const ultima = susBoletas.length > 0 ? toMillis(susBoletas[0].fecha) : null;
          return {
            ...inspector,
            boletas: susBoletas.length,
            conformes: susBoletas.filter((b) => b.conforme === "Sí").length,
            noConformes: susBoletas.filter((b) => b.conforme === "No").length,
            ultimaActividad: ultima,
          };
        });

      return {
        totalBoletas: boletas.length,
        totalConformes,
        totalNoConformes,
        totalParciales,
        totalMultas,
        inspectoresActivos: inspectores.filter((i) => i.estado === "Activo").length,
        totalInspectores: inspectores.length,
        boletasRecientes: boletas.slice(0, 5).map((b) => ({
          ...b,
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