import { Schema, model, Document, Types } from 'mongoose';
import {
  DIFFICULTIES,
  Difficulty,
  FREQUENCY_TYPES,
  FrequencyType,
  PRIORITIES,
  Priority,
} from './enums';
import { jsonOptions } from './toJSON';

/**
 * An Action is a PLAN (a rule), not a to-do row.
 * The dated instances it produces live in ActionOccurrence -- that separation is
 * what makes "today", "missed", streaks and the calendar cheap to query.
 */
export interface IAction extends Document {
  _id: Types.ObjectId;
  user: Types.ObjectId;
  goal: Types.ObjectId;
  milestone?: Types.ObjectId;
  title: string;
  description?: string;
  estimatedMinutes: number;
  difficulty: Difficulty;
  priority: Priority;
  isRecurring: boolean;
  recurrence: {
    type: FrequencyType;
    days: number[];
    timesPerWeek: number;
    endDate?: Date;
  };
  /** only for one-off actions (recurrence.type = 'once') */
  dueDate?: Date;
  /** "HH:mm" local; falls back to the goal routine, then user preferences */
  preferredTime?: string;
  /** e.g. "learn 20 words" -> targetCount 20, unit "words" */
  targetCount?: number;
  unit?: string;
  isActive: boolean;
  /** the date up to which occurrences have been generated */
  materialisedUntil?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const actionSchema = new Schema<IAction>(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    goal: { type: Schema.Types.ObjectId, ref: 'Goal', required: true, index: true },
    milestone: { type: Schema.Types.ObjectId, ref: 'Milestone', index: true },
    title: { type: String, required: true, trim: true, maxlength: 120 },
    description: { type: String, maxlength: 600 },
    estimatedMinutes: { type: Number, default: 30, min: 5, max: 480 },
    difficulty: { type: String, enum: DIFFICULTIES, default: 'medium' },
    priority: { type: String, enum: PRIORITIES, default: 'medium' },
    isRecurring: { type: Boolean, default: true },
    recurrence: {
      type: new Schema(
        {
          type: { type: String, enum: FREQUENCY_TYPES, default: 'specific_days' },
          days: { type: [Number], default: [] },
          timesPerWeek: { type: Number, default: 3 },
          endDate: { type: Date },
        },
        { _id: false },
      ),
      default: () => ({}),
    },
    dueDate: { type: Date },
    preferredTime: { type: String },
    targetCount: { type: Number },
    unit: { type: String, maxlength: 20 },
    isActive: { type: Boolean, default: true },
    materialisedUntil: { type: Date },
  },
  { timestamps: true },
);

actionSchema.index({ user: 1, isActive: 1 });
actionSchema.index({ goal: 1, milestone: 1 });

actionSchema.set('toJSON', jsonOptions());

export const Action = model<IAction>('Action', actionSchema);
