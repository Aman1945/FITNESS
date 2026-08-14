import { Schema, model, Document, Types } from 'mongoose';
import {
  FREQUENCY_TYPES,
  FrequencyType,
  GOAL_CATEGORIES,
  GOAL_STATUSES,
  GoalCategory,
  GoalStatus,
  PRIORITIES,
  PROGRESS_STATUSES,
  Priority,
  ProgressStatus,
  TIME_OF_DAY,
  TimeOfDay,
} from './enums';
import { jsonOptions } from './toJSON';

export interface IRoutine {
  type: FrequencyType;
  /** used when type = specific_days; 0 = Sunday */
  days: number[];
  /** used when type = weekly_count */
  timesPerWeek: number;
  timeOfDay: TimeOfDay;
  /** "HH:mm" local to the user */
  startTime: string;
  durationMinutes: number;
}

export interface IGoal extends Document {
  _id: Types.ObjectId;
  user: Types.ObjectId;
  title: string;
  description?: string;
  /** "why this matters" -- kept because motivation is part of the product, not decoration */
  why?: string;
  category: GoalCategory;
  customCategory?: string;
  priority: Priority;
  startDate: Date;
  targetDate: Date;
  routine: IRoutine;
  status: GoalStatus;
  /** cached derived fields, recomputed by the status service */
  progressPercent: number;
  computedStatus: ProgressStatus;
  statusReason: string;
  lastEvaluatedAt?: Date;
  completedAt?: Date;
  pausedAt?: Date;
  color?: string;
  createdAt: Date;
  updatedAt: Date;
}

const routineSchema = new Schema<IRoutine>(
  {
    type: { type: String, enum: FREQUENCY_TYPES, default: 'specific_days' },
    days: { type: [Number], default: [1, 3, 5] },
    timesPerWeek: { type: Number, default: 3, min: 1, max: 7 },
    timeOfDay: { type: String, enum: TIME_OF_DAY, default: 'evening' },
    startTime: { type: String, default: '19:00' },
    durationMinutes: { type: Number, default: 30, min: 5, max: 480 },
  },
  { _id: false },
);

const goalSchema = new Schema<IGoal>(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    title: { type: String, required: true, trim: true, maxlength: 120 },
    description: { type: String, maxlength: 1000 },
    why: { type: String, maxlength: 500 },
    category: { type: String, enum: GOAL_CATEGORIES, default: 'personal' },
    customCategory: { type: String, maxlength: 40 },
    priority: { type: String, enum: PRIORITIES, default: 'medium' },
    startDate: { type: Date, required: true, default: Date.now },
    targetDate: { type: Date, required: true },
    routine: { type: routineSchema, default: () => ({}) },
    status: { type: String, enum: GOAL_STATUSES, default: 'active', index: true },
    progressPercent: { type: Number, default: 0, min: 0, max: 100 },
    computedStatus: { type: String, enum: PROGRESS_STATUSES, default: 'on_track' },
    statusReason: { type: String, default: 'Just getting started.' },
    lastEvaluatedAt: { type: Date },
    completedAt: { type: Date },
    pausedAt: { type: Date },
    color: { type: String },
  },
  { timestamps: true },
);

goalSchema.index({ user: 1, status: 1, targetDate: 1 });

goalSchema.virtual('displayCategory').get(function (this: IGoal) {
  return this.category === 'custom' && this.customCategory
    ? this.customCategory
    : this.category;
});

goalSchema.set('toJSON', jsonOptions());

export const Goal = model<IGoal>('Goal', goalSchema);
