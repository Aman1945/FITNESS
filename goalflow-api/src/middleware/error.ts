import { NextFunction, Request, Response } from 'express';
import mongoose from 'mongoose';
import { ApiError } from '../utils/ApiError';
import { logger } from '../config/logger';
import { isProd } from '../config/env';
import { labelFor, summarise } from './humanize';

export function notFoundHandler(req: Request, _res: Response, next: NextFunction) {
  next(ApiError.notFound(`Route ${req.method} ${req.originalUrl} not found`));
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorHandler(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction,
) {
  let apiError: ApiError;

  if (err instanceof ApiError) {
    apiError = err;
  } else if (err instanceof mongoose.Error.ValidationError) {
    // Database-level validation slipped past the edge schema: still report it
    // in the same readable shape rather than leaking Mongoose wording.
    const details = Object.values(err.errors).map((e) => ({
      field: e.path,
      label: labelFor(e.path),
      message: `${labelFor(e.path)} is not valid.`,
    }));
    apiError = ApiError.badRequest(summarise(details), details);
  } else if (err instanceof mongoose.Error.CastError) {
    apiError = ApiError.badRequest(`${labelFor(err.path)} is not in the expected format.`);
  } else if ((err as { code?: number }).code === 11000) {
    const field = Object.keys((err as { keyPattern?: object }).keyPattern ?? {})[0];
    apiError = ApiError.conflict(
      field === 'email'
        ? 'An account with this email already exists.'
        : `${labelFor(field ?? '')} is already taken.`,
    );
  } else if (err instanceof SyntaxError && 'body' in (err as object)) {
    apiError = ApiError.badRequest('We could not read that request. Please try again.');
  } else {
    apiError = ApiError.internal();
  }

  const log = { err, path: req.originalUrl, method: req.method, userId: req.userId };
  if (apiError.statusCode >= 500) logger.error(log, 'Unhandled error');
  else logger.warn({ ...log, code: apiError.code }, apiError.message);

  res.status(apiError.statusCode).json({
    success: false,
    error: {
      code: apiError.code,
      message: apiError.message,
      ...(apiError.details ? { details: apiError.details } : {}),
      ...(isProd || apiError.statusCode < 500
        ? {}
        : { stack: (err as Error)?.stack }),
    },
  });
}
