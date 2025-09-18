import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import cors from "cors";
import express from "express";

const app = express();
const corsMiddleware = cors({ origin: true });
app.use(corsMiddleware);
app.use(express.json());
app.options("*", corsMiddleware);

function validarCampos(body) {
  const requeridos = [
    "type","requestId","requestTitle","rating","reviewComment",
    "raterName","requesterId","helperId","ratedUserId"
  ];
  return requeridos.filter(k => body?.[k] === undefined || body?.[k] === null || body?.[k] === "");
}

app.post("/", async (req, res) => {
  logger.info("INICIO sendRatingNotification", { body: req.body || {} });
  let body = req.body;
  if (!body || (typeof body === "object" && Object.keys(body).length === 0)) {
    try { if (req.rawBody?.length) body = JSON.parse(Buffer.from(req.rawBody).toString("utf8")); } catch {}
  }
  const faltantes = validarCampos(body);
  if (faltantes.length) {
    logger.warn("Faltan parámetros obligatorios", { faltantes });
    return res.status(400).json({ ok:false, error:"Faltan parámetros obligatorios", faltantes });
  }
  try {
    logger.info("sendRatingNotification OK", { requestId: body.requestId, ratedUserId: body.ratedUserId });
    return res.status(200).json({ ok: true, requestId: body.requestId });
  } catch (err) {
    logger.error("Error interno en sendRatingNotification", { err: String(err) });
    return res.status(500).json({ ok:false, error:"Error interno" });
  }
});

app.all("*", (_req, res) => res.status(405).send("Method Not Allowed"));

export const sendRatingNotification = onRequest(
  { region: "us-central1", cors: true, timeoutSeconds: 30, memory: "256MiB" },
  app
);
