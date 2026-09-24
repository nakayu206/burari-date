import { initializeApp } from "firebase-admin/app";
import { onRequest } from "firebase-functions/v2/https";

initializeApp();

export const ping = onRequest((req, res) => {
  res.status(200).send("ok");
});

export { getCandidates } from "./candidates";
