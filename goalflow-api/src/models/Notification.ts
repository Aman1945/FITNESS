import { Schema, model, Document, Types } from 'mongoose';
import { NOTIFICATION_TYPES, NotificationType } from './enums';
import { jsonOptions } from './toJSON';

/** In-app notification feed + delivery audit log. */
export interface INotification extends Document {
  _id: Types.ObjectId;
  user: Types.ObjectId;
  type: NotificationType;
  title: string;
  body: string;
  data: Record<string, string>;
  readAt?: Date;
  channels: { push?: 'sent' | 'failed' | 'skipped'; email?: 'sent' | 'failed' | 'skipped' };
  createdAt: Date;
  updatedAt: Date;
}

const notificationSchema = new Schema<INotification>(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    type: { type: String, enum: NOTIFICATION_TYPES, required: true },
    title: { type: String, required: true },
    body: { type: String, required: true },
    data: { type: Object, default: {} },
    readAt: { type: Date },
    channels: { type: Object, default: {} },
  },
  { timestamps: true },
);

notificationSchema.index({ user: 1, createdAt: -1 });

notificationSchema.set('toJSON', jsonOptions());

export const Notification = model<INotification>('Notification', notificationSchema);
