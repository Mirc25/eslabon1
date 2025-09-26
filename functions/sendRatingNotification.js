import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import cors from "cors";
import express from "express";
import admin from "firebase-admin";

try { admin.app(); } catch { admin.initializeApp(); }
const db = admin.firestore();

const app = express();
const corsMiddleware = cors({ origin: true });
app.use(corsMiddleware);
app.use(express.json());
app.options("*", corsMiddleware);

function validarCampos(body) {
  const reqs = ["type","requestId","requestTitle","rating","reviewComment","raterName","requesterId","helperId","ratedUserId"];
  return reqs.filter(k => body?.[k] === undefined || body?.[k] === null || body?.[k] === "");
}

app.post("/", async (req, res) => {
  logger.info("INICIO sendRatingNotification", { body: req.body || {} });

  let body = req.body;
  if (!body || (typeof body === "object" && Object.keys(body).length === 0)) {
    try { if (req.rawBody?.length) body = JSON.parse(Buffer.from(req.rawBody).toString("utf8")); } catch {}
  }

  const faltantes = validarCampos(body);
  if (faltantes.length) return res.status(400).json({ ok:false, error:"Faltan parámetros obligatorios", faltantes });

  try {
    const ratedUserId = String(body.ratedUserId);

    // token por body (prueba) o Firestore
    let token = body.deviceToken || null;
    if (!token) {
      const snap = await db.collection("users").doc(ratedUserId).get();
      const u = snap.data() || {};
      token = u.fcmToken || u.deviceToken || u.token || null;
    }
    if (!token) {
      logger.warn("Usuario sin FCM token", { ratedUserId });
      return res.status(200).json({ ok:true, requestId: body.requestId, sent:false, reason:"no_token" });
    }

    const isHelper = body.type === "rate_helper";

    // Ruta por type con requestId incluido
    let routeFromType = "/";
    if (body.type === "chat") {
      routeFromType = "/chat";
    } else if (body.type === "rate_helper") {
      routeFromType = `/rate-helper/${body.requestId}`;
      if (body.helperId && body.raterName) {
        routeFromType += `?helperId=${body.helperId}&helperName=${encodeURIComponent(body.raterName)}`;
      }
    } else if (body.type === "rate_requester") {
      routeFromType = `/rate-requester/${body.requestId}`;
      if (body.requesterId && body.raterName) {
        routeFromType += `?requesterId=${body.requesterId}&requesterName=${encodeURIComponent(body.raterName)}`;
      }
    } else if (body.type === "ranking") {
      routeFromType = "/ranking";
    }

    const notification = {
      title: isHelper ? "¡Te calificaron como ayudador!" : "¡Te calificaron como solicitante!",
      body: `${body.raterName} te dejó ${body.rating}⭐ · ${body.requestTitle}`,
    };

    const data = {
      type: String(body.type),
      route: String(body.route || routeFromType), // permite override desde el body
      requestId: String(body.requestId || ""),
      requesterId: String(body.requesterId || ""),
      helperId: String(body.helperId || ""),
      chatRoomId: String(body.chatRoomId || ""),
      rating: String(body.rating ?? ""),
      reviewComment: String(body.reviewComment || ""),
      requestTitle: String(body.requestTitle || "")
    };

    const messageId = await admin.messaging().send({
      token,
      notification,
      data,
      android: { priority: "high", notification: { channelId: "default" } }
    });

    logger.info("sendRatingNotification OK", { requestId: body.requestId, ratedUserId, messageId });
    return res.status(200).json({ ok:true, requestId: body.requestId, sent:true, messageId });
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
