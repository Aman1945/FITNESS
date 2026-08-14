import { Schema, model, Document, Types } from 'mongoose';
import { OCCURRENCE_STATUSES, OccurrenceStatus, Priority, PRIORITIES } from './enums';
import { jsonOptions } from './toJSON';

/**
 * One dated instance of an Action -- the append-only LOG.
 * Occurrences are never deleted, only status-changed, which is how the app keeps
 * history (JD section 6) and answers "did I miss Monday?".
 */
export interface IActionOccurrence extends Document {
  _id: Types.ObjectId;
  user: Types.ObjectId;
  action: Types.ObjectId;
  goal: Types.ObjectId;
  milestone?: Types.ObjectId;
  /** midnight UTC marker for the user's local calendar day */
  scheduledDate: Date;
  /** exact local datetime, used as the reminder trigger */
  scheduledAt: Date;
  title: string;
  estimatedMinutes: number;
  priority: Priority;
  status: OccurrenceStatus;
  startedAt?: Date;
  completedAt?: Date;
  actualMinutes?: number;
  note?: string;
  reminderSentAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const occurrenceSchema = new Schema<IActionOccurrence>(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    action: { type: Schema.Types.ObjectId, ref: 'Action', required: true, index: true },
    goal: { type: Schema.Types.ObjectId, ref: 'Goal', required: true, index: true },
    milestone: { type: Schema.Types.ObjectId, ref: 'Milestone' },
    scheduledDate: { type: Date, required: true, index: true },
    scheduledAt: { type: Date, required: true },
    // Denormalised so the "today" feed and calendar need no populate.
    title: { type: String, required: true },
    estimatedMinutes: { type: Number, default: 30 },
    priority: { type: String, enum: PRIORITIES, default: 'medium' },
    status: {
      type: String,
      enum: OCCURRENCE_STATUSES,
      default: 'upcoming',
      index: true,
    },
    startedAt: { type: Date },
    completedAt: { type: Date },
    actualMinutes: { type: Number },
    note: { type: String, maxlength: 500 },
    reminderSentAt: { type: Date },
  },
  { timestamps: true },
);

// Idempotent materialisation: the cron can run twice without duplicating rows.
occurrenceSchema.index({ action: 1, scheduledDate: 1 }, { unique: true });
occurrenceSchema.index({ user: 1, scheduledDate: 1, status: 1 });
occurrenceSchema.index({ goal: 1, scheduledDate: 1 });
occurrenceSchema.index({ status: 1, scheduledAt: 1 }); // reminder sweep

occurrenceSchema.set('toJSON', jsonOptions());

export const ActionOccurrence = model<IActionOccurrence>(
  'ActionOccurrence',
  occurrenceSchema,
);
