import { NextFunction, Request, Response } from 'express';
import { AnyZodObject, ZodError } from 'zod';
import { ApiError } from '../utils/ApiError';
import { humanizeIssue, summarise } from './humanize';

/**
 * Validation happens at the edge, once. Controllers and services can therefore
 * trust their inputs -- no defensive re-checking further down.
 *
 * Failures come back as user-readable sentences (see humanize.ts), each tagged
 * with the field and its label, so the client can show them inline or as one
 * summary without ever surfacing a raw Zod message.
 */
export const validate =
  (schema: AnyZodObject) =>
  (req: Request, _res: Response, next: NextFunction) => {
    try {
      const parsed = schema.parse({
        body: req.body,
        query: req.query,
        params: req.params,
      });
      if (parsed.body) req.body = parsed.body;
      if (parsed.query) Object.assign(req.query, parsed.query);
      if (parsed.params) Object.assign(req.params, parsed.params);
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        // Keep only the first problem per field so a single input never shows
        // three stacked complaints.
        const seen = new Set<string>();
        const details = err.errors
          .map(humanizeIssue)
          .filter((d) => {
            if (seen.has(d.field)) return false;
            seen.add(d.field);
            return true;
          });

        return next(ApiError.badRequest(summarise(details), details));
      }
      next(err);
    }
  };
