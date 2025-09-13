// functions/src/index.ts

import {onRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {PDFDocument, rgb, StandardFonts} from "pdf-lib";
import {format} from "date-fns-tz";
import type {Request, Response} from "express";

admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage().bucket();

export const verificarBoleta = onRequest(
  {
    region: "southamerica-west1",
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

      const fileResponse =
        await storage.file("firmas/firma_gerente.png").download();
      const firmaBytes = fileResponse[0];

      const pdfDoc = await PDFDocument.create();
      const page = pdfDoc.addPage();
      const font = await pdfDoc.embedFont(StandardFonts.Helvetica);
      const fontBold = await pdfDoc.embedFont(StandardFonts.HelveticaBold);
      const {height} = page.getSize();
      const firmaImage = await pdfDoc.embedPng(firmaBytes);

      let y = height - 50;
      const margin = 50;

      const drawText = (
        text: string,
        size: number,
        isBold = false
      ) => {
        page.drawText(text, {
          x: margin,
          y: y,
          size: size,
          font: isBold ? fontBold : font,
          color: rgb(0, 0, 0),
        });
        y -= size * 1.5;
      };

      drawText("ACTA DE CONTROL DE TRANSPORTE", 22, true);
      drawText("MUNICIPALIDAD DISTRITAL DE LA JOYA", 14);
      y -= 20;

      const fecha = boletaData.fecha.toDate();
      const fechaFormateada = format(fecha, "dd/MM/yyyy HH:mm:ss", {
        timeZone: "America/Lima",
      });

      drawText(`Fecha: ${fechaFormateada}`, 12);
      drawText(`Placa: ${boletaData.placa}`, 12);
      drawText(`Empresa: ${boletaData.empresa}`, 12);
      drawText(`Inspector: ${boletaData.inspectorEmail}`, 12);
      y -= 15;

      drawText("Motivo:", 12, true);
      drawText(boletaData.motivo, 11);
      y -= 10;

      // Aquí puedes añadir los otros campos que guardas en la boleta
      drawText("Conforme:", 12, true);
      drawText(boletaData.conforme || "No especificado.", 11);
      y -= 10;

      drawText("Observaciones:", 12, true);
      drawText(boletaData.observaciones || "Ninguna.", 11);
      y -= 100;

      page.drawImage(firmaImage, {
        x: margin,
        y: y,
        width: 120,
        height: 50,
      });
      drawText("________________________", 12);
      drawText("Gerente de Transportes", 11);

      const pdfBytes = await pdfDoc.save();
      response.setHeader("Content-Type", "application/pdf");
      response.setHeader(
        "Content-Disposition",
        `inline; filename="boleta_${boletaId}.pdf"`
      );
      response.send(Buffer.from(pdfBytes));
    } catch (error) {
      console.error("Error al generar el PDF:", error);
      response.status(500).send("Error interno al generar el PDF.");
    }
  });
