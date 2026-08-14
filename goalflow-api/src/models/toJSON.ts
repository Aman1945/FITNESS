/**
 * Shared JSON shape for every document the API returns:
 *   _id -> id, no __v, and any sensitive keys stripped.
 * Defined once so responses stay consistent across modules.
 */
export function jsonOptions(hidden: string[] = []) {
  return {
    virtuals: true,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    transform: (_doc: any, ret: any) => {
      ret.id = String(ret._id);
      delete ret._id;
      delete ret.__v;
      for (const key of hidden) delete ret[key];
      return ret;
    },
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as any;
}
