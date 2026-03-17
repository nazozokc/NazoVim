/**
 * {{_file_name_}}
 * created: {{_date_}}
 */

import { Router, Request, Response } from "express";

const router = Router();

router.get("/", async (req: Request, res: Response) => {
  res.json({ ok: true });
});

export default router;
