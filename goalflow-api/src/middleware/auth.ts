import { NextFunction, Request, Response } from 'express';
import { Model, Types } from 'mongoose';
import { verifyAccessToken } from '../modules/auth/token.service';
import { User, IUser } from '../models/User';
import { ApiError } from '../utils/ApiError';

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      user?: IUser;
      userId?: string;
    }
  }
}

export async function requireAuth(req: Request, _res: Response, next: NextFunction) {
  try {
    const header = req.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw ApiError.unauthorized('Missing bearer token');
    }
    const payload = verifyAccessToken(header.slice(7));
    const user = await User.findById(payload.sub);
    if (!user) throw ApiError.unauthorized('Account no longer exists');

    req.user = user;
    req.userId = user.id;
    next();
  } catch (err) {
    next(err instanceof ApiError ? err : ApiError.unauthorized('Invalid or expired token'));
  }
}

/**
 * Ownership guard. Authorization is enforced here rather than trusting that every
 * query remembered to filter by user.
 */
export const requireOwnership =
  <T extends { user: Types.ObjectId }>(
    modelGetter: () => Model<T>,
    paramName = 'id',
    attachAs = 'resource',
  ) =>
  async (req: Request, _res: Response, next: NextFunction) => {
    try {
      const id = req.params[paramName];
      if (!Types.ObjectId.isValid(id)) throw ApiError.badRequest('Invalid id');

      const doc = await modelGetter().findById(id);
      if (!doc) throw ApiError.notFound();
      if (String(doc.user) !== req.userId) throw ApiError.forbidden();

      (req as unknown as Record<string, unknown>)[attachAs] = doc;
      next();
    } catch (err) {
      next(err);
    }
  };
