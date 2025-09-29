import * as functions from "firebase-functions";
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
    return null;
  } catch {
    return null;
  }
};

const toMillis = (v: AnyDate): number | null => {
  const d = toDateSafe(v);
  return d ? d.getTime() : null;
};

// ===================== FUNCIÓN PARA GENERAR PDF =====================
export const generateBoletaPdf = onCall(
  {region: "southamerica-west1"},
  async (request) => {
    const {boletaId} = request.data;
    if (!boletaId) {
      throw new HttpsError("invalid-argument", "ID de boleta requerido");
    }

    try {
      const boletaDoc = await db.collection("boletas").doc(boletaId).get();
      if (!boletaDoc.exists) {
        throw new HttpsError("not-found", "Boleta no encontrada");
      }

      const boleta = boletaDoc.data()!;
      const pdfDoc = await PDFDocument.create();
      const page = pdfDoc.addPage([595.28, 841.89]); // A4
      const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
      const boldFont = await pdfDoc.embedFont(StandardFonts.HelveticaBold);

      const {width, height} = page.getSize();
      let yPosition = height - 50;

      // Función auxiliar para agregar texto
      const addText = (text: string, x: number, size: number, isBold = false) => {
        page.drawText(text, {
          x,
          y: yPosition,
          size,
          font: isBold ? boldFont : font,
          color: textoGris,
        });
        yPosition -= size + 5;
      };

      // Encabezado
      addText("MUNICIPALIDAD DISTRITAL DE LA JOYA", 50, 18, true);
      addText("GERENCIA DE TRANSPORTE", 50, 14, true);
      yPosition -= 20;

      addText("BOLETA DE FISCALIZACIÓN", 50, 16, true);
      addText(`ACTA DE CONTROL Nro: ${boletaId.substring(0, 8).toUpperCase()}`, 50, 12);
      yPosition -= 20;

      // Datos de la boleta
      const fechaStr = boleta.fecha ? formatInTimeZone(
        toDateSafe(boleta.fecha) || new Date(),
        "America/Lima",
        "dd/MM/yyyy HH:mm"
      ) : "No especificada";

      addText(`Fecha y Hora: ${fechaStr}`, 50, 12);
      addText(`Placa: ${boleta.placa || "No especificada"}`, 50, 12);
      addText(`Conductor: ${boleta.conductor || boleta.nombreConductor || "No especificado"}`, 50, 12);
      addText(`Empresa: ${boleta.empresa || "No especificada"}`, 50, 12);
      addText(`Motivo: ${boleta.motivo || "No especificado"}`, 50, 12);
      addText(`Conforme: ${boleta.conforme || "No especificado"}`, 50, 12);

      if (boleta.multa && boleta.multa > 0) {
        addText(`Multa: S/ ${boleta.multa.toFixed(2)}`, 50, 12);
      }

      if (boleta.observaciones) {
        yPosition -= 10;
        addText("Observaciones:", 50, 12, true);
        addText(boleta.observaciones, 50, 10);
      }

      // Generar PDF
      const pdfBytes = await pdfDoc.save();
      const fileName = `boleta_${boletaId}_${Date.now()}.pdf`;
      const file = storage.file(`pdfs/${fileName}`);

      await file.save(Buffer.from(pdfBytes), {
        metadata: {contentType: "application/pdf"},
      });

      // Hacer el archivo público
      await file.makePublic();
      const publicUrl = `https://storage.googleapis.com/${storage.name}/pdfs/${fileName}`;

      return {success: true, url: publicUrl};
    } catch (error) {
      console.error("Error generando PDF:", error);
      throw new HttpsError("internal", "Error al generar PDF");
    }
  }
);

// ===================== FUNCIÓN PARA VERIFICAR BOLETA =====================
export const verificarBoleta = functions.https.onRequest(
  { region: "southamerica-west1" },
  async (req: Request, res: Response) => {
    const {id} = req.query;
    if (!id || typeof id !== "string") {
      res.status(400).send("ID de boleta requerido");
      return;
    }

    try {
      const boletaDoc = await db.collection("boletas").doc(id).get();
      if (!boletaDoc.exists) {
        res.status(404).send("Boleta no encontrada");
        return;
      }

      const boleta = boletaDoc.data()!;
      const fechaStr = boleta.fecha ? formatInTimeZone(
        toDateSafe(boleta.fecha) || new Date(),
        "America/Lima",
        "dd/MM/yyyy HH:mm"
      ) : "No especificada";

      const html = `
        <!DOCTYPE html>
        <html>
        <head>
          <title>Verificación de Boleta</title>
          <meta charset="utf-8">
          <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            .header { text-align: center; margin-bottom: 30px; }
            .valid { color: green; font-weight: bold; }
            .detail { margin: 10px 0; }
            .label { font-weight: bold; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>MUNICIPALIDAD DISTRITAL DE LA JOYA</h1>
            <h2>GERENCIA DE TRANSPORTE</h2>
            <p class="valid">✓ BOLETA VÁLIDA</p>
          </div>
          <div class="detail"><span class="label">ID:</span> ${id}</div>
          <div class="detail"><span class="label">Fecha:</span> ${fechaStr}</div>
          <div class="detail"><span class="label">Placa:</span> ${boleta.placa || "No especificada"}</div>
          <div class="detail"><span class="label">Conductor:</span> ${boleta.conductor || boleta.nombreConductor || "No especificado"}</div>
          <div class="detail"><span class="label">Empresa:</span> ${boleta.empresa || "No especificada"}</div>
          <div class="detail"><span class="label">Motivo:</span> ${boleta.motivo || "No especificado"}</div>
          <div class="detail"><span class="label">Conforme:</span> ${boleta.conforme || "No especificado"}</div>
          ${boleta.multa && boleta.multa > 0 ? `<div class="detail"><span class="label">Multa:</span> S/ ${boleta.multa.toFixed(2)}</div>` : ""}
        </body>
        </html>
      `;

      res.setHeader("Content-Type", "text/html; charset=utf-8");
      res.send(html);
    } catch (error) {
      console.error("Error verificando boleta:", error);
      res.status(500).send("Error interno del servidor");
    }
  });

// ✅ CORREGIDO: Función getDashboardData mejorada para contar correctamente
export const getDashboardData = onCall(
  { region: "southamerica-west1" },
  async (request) => {
    // Verificar permisos
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Usuario no autenticado.");
    }

    try {
      const userDoc = await db.collection("users").doc(request.auth.uid).get();
      const userData = userDoc.data();
      
      if (!userData || (userData.role !== "gerente" && userData.rol !== "gerente")) {
        throw new HttpsError("permission-denied", "Acceso denegado. Solo gerentes pueden ver el dashboard.");
      }

      // Obtener datos en paralelo
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

      // ✅ MEJORADO: Cálculos más precisos
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      
      // Filtrar boletas de hoy
      const boletasHoy = boletas.filter(boleta => {
        const boletaDate = toDateSafe(boleta.fecha);
        if (!boletaDate) return false;
        const boletaDay = new Date(boletaDate.getFullYear(), boletaDate.getMonth(), boletaDate.getDate());
        return boletaDay.getTime() === today.getTime();
      });

      // Calcular KPIs
      const totalBoletas = boletas.length;
      const boletasHoyCount = boletasHoy.length;
      const totalMultas = boletas.reduce((sum, b) => sum + (b.multa || 0), 0);
      const totalConformes = boletas.filter((b) => b.conforme === "Sí" || b.conforme === "Si").length;
      const totalNoConformes = boletas.filter((b) => b.conforme === "No").length;
      const totalParciales = boletas.filter((b) => b.conforme === "Parcial" || b.conforme === "Parcialmente").length;
      
      // ✅ CORREGIDO: Filtrar inspectores correctamente
      const inspectores = users
        .filter((u) => u.role === "inspector" || u.rol === "inspector") // Verificar ambos campos
        .map((inspector) => {
          const inspectorKey = inspector.uid || inspector.id;
          const susBoletas = boletas.filter((b) => b.inspectorId === inspectorKey);
          const ultima = susBoletas.length > 0 ? toMillis(susBoletas[0].fecha) : null;
          return {
            ...inspector,
            boletas: susBoletas.length,
            conformes: susBoletas.filter((b) => b.conforme === "Sí" || b.conforme === "Si").length,
            noConformes: susBoletas.filter((b) => b.conforme === "No").length,
            ultimaActividad: ultima,
          };
        });

      // ✅ NUEVO: Datos para gráficos por mes
      const boletasPorMes = Array.from({length: 12}, (_, i) => {
        const mes = i;
        const año = now.getFullYear();
        return boletas.filter(boleta => {
          const boletaDate = toDateSafe(boleta.fecha);
          if (!boletaDate) return false;
          return boletaDate.getMonth() === mes && boletaDate.getFullYear() === año;
        }).length;
      });

      // ✅ NUEVO: Multas pendientes (boletas activas con multa)
      const multasPendientes = boletas.filter(b => 
        (b.estado === "Activa" || !b.estado) && 
        b.multa && 
        b.multa > 0
      ).length;

      // ✅ NUEVO: Total recaudado (multas de boletas pagadas)
      const totalRecaudado = boletas
        .filter(b => b.estado === "Pagada")
        .reduce((sum, b) => sum + (b.multa || 0), 0);

      return {
        totalBoletas,
        boletasHoy: boletasHoyCount,
        totalConformes,
        totalNoConformes,
        totalParciales,
        totalMultas,
        multasPendientes,
        totalRecaudado,
        inspectoresActivos: inspectores.filter((i) => i.estado === "Activo").length,
        totalInspectores: inspectores.length,
        boletasPorMes,
        boletasRecientes: boletas.slice(0, 5).map((b) => ({
          ...b,
          fecha: toMillis(b.fecha),
        })),
        inspectores: inspectores.map(inspector => ({
          ...inspector,
          ultimaActividad: inspector.ultimaActividad,
        })),
      };
    } catch (error) {
      console.error("Error al obtener datos del dashboard:", error);
      throw new HttpsError("internal", "No se pudieron cargar los datos del dashboard.");
    }
  }
);


// ✅ CORREGIDO: Trigger para actualizar estadísticas cuando se crea una boleta
// Import v1 functions for Firestore triggers
import * as functionsV1 from "firebase-functions/v1";

export const onBoletaCreated = functionsV1.firestore
  .document("boletas/{boletaId}")
  .onCreate(async (snap, context) => {
    try {
      const boleta = snap.data();
      const now = new Date();
      const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      
      // Actualizar estadísticas diarias
      const statsRef = db.collection("stats").doc(today.toISOString().split('T')[0]);
      
      await statsRef.set({
        fecha: admin.firestore.Timestamp.fromDate(today),
        totalBoletas: admin.firestore.FieldValue.increment(1),
        totalMultas: admin.firestore.FieldValue.increment(boleta.multa || 0),
        ultimaActualizacion: admin.firestore.Timestamp.now(),
      }, { merge: true });

      // Actualizar estadísticas del inspector
      if (boleta.inspectorId) {
        const inspectorStatsRef = db.collection("inspectorStats").doc(boleta.inspectorId);
        await inspectorStatsRef.set({
          totalBoletas: admin.firestore.FieldValue.increment(1),
          ultimaBoleta: admin.firestore.Timestamp.now(),
        }, { merge: true });
      }

      console.log(`Estadísticas actualizadas para boleta ${context.params.boletaId}`);
    } catch (error) {
      console.error("Error actualizando estadísticas:", error);
    }
  });

// ===================== FUNCIÓN PARA OBTENER INSPECTORES =====================
export const getInspectores = onCall(
  {region: "southamerica-west1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Usuario no autenticado");
    }

    try {
      const userDoc = await db.collection("users").doc(request.auth.uid).get();
      const userData = userDoc.data();
      
      if (!userData || (userData.role !== "gerente" && userData.rol !== "gerente")) {
        throw new HttpsError("permission-denied", "Solo gerentes pueden ver inspectores");
      }

      const inspectoresSnapshot = await db
        .collection("users")
        .where("role", "==", "inspector")
        .get();

      const inspectores = inspectoresSnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));

      return {inspectores};
    } catch (error) {
      console.error("Error obteniendo inspectores:", error);
      throw new HttpsError("internal", "Error al obtener inspectores");
    }
  }
);

// ===================== FUNCIÓN PARA CREAR INSPECTOR =====================
export const createInspector = onCall(
  {region: "southamerica-west1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Usuario no autenticado");
    }

    const {email, name, code, phone} = request.data;
    if (!email || !name || !code) {
      throw new HttpsError("invalid-argument", "Datos incompletos");
    }

    try {
      const userDoc = await db.collection("users").doc(request.auth.uid).get();
      const userData = userDoc.data();
      
      if (!userData || (userData.role !== "gerente" && userData.rol !== "gerente")) {
        throw new HttpsError("permission-denied", "Solo gerentes pueden crear inspectores");
      }

      // Crear usuario en Authentication
      const userRecord = await admin.auth().createUser({
        email,
        password: "inspector123", // Contraseña temporal
        displayName: name,
      });

      // Crear documento en Firestore
      await db.collection("users").doc(userRecord.uid).set({
        email,
        name,
        code,
        phone: phone || "",
        role: "inspector",
        status: "Activo",
        createdAt: admin.firestore.Timestamp.now(),
        createdBy: request.auth.uid,
      });

      return {success: true, uid: userRecord.uid};
    } catch (error) {
      console.error("Error creando inspector:", error);
      throw new HttpsError("internal", "Error al crear inspector");
    }
  }
);

// ===================== FUNCIÓN PARA ACTUALIZAR INSPECTOR =====================
export const updateInspector = onCall(
  {region: "southamerica-west1"},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Usuario no autenticado");
    }

    const {inspectorId, name, code, phone, status} = request.data;
    if (!inspectorId) {
      throw new HttpsError("invalid-argument", "ID de inspector requerido");
    }

    try {
      const userDoc = await db.collection("users").doc(request.auth.uid).get();
      const userData = userDoc.data();
      
      if (!userData || (userData.role !== "gerente" && userData.rol !== "gerente")) {
        throw new HttpsError("permission-denied", "Solo gerentes pueden actualizar inspectores");
      }

      const updateData: any = {
        updatedAt: admin.firestore.Timestamp.now(),
        updatedBy: request.auth.uid,
      };

      if (name) updateData.name = name;
      if (code) updateData.code = code;
      if (phone !== undefined) updateData.phone = phone;
      if (status) updateData.status = status;

      await db.collection("users").doc(inspectorId).update(updateData);

      return {success: true};
    } catch (error) {
      console.error("Error actualizando inspector:", error);
      throw new HttpsError("internal", "Error al actualizar inspector");
    }
  }
);
