import { Schema, model, Document, Types } from 'mongoose';
import { jsonOptions } from './toJSON';

export interface IWeeklyReflection extends Document {
  _id: Types.ObjectId;
  user: Types.ObjectId;
  weekStart: Date;
  weekEnd: Date;
  stats: {
    planned: number;
    completed: number;
    missed: number;
    skipped: number;
    completionRate: number;
    goalsWorkedOn: number;
    strongestGoalTitle?: string;
    weakestGoalTitle?: string;
    minutesInvested: number;
  };
  wentWell?: string;
  wasDifficult?: string;
  improveNext?: string;
  submittedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const reflectionSchema = new Schema<IWeeklyReflection>(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    weekStart: { type: Date, required: true },
    weekEnd: { type: Date, required: true },
    stats: {
      planned: { type: Number, default: 0 },
      completed: { type: Number, default: 0 },
      missed: { type: Number, default: 0 },
      skipped: { type: Number, default: 0 },
      completionRate: { type: Number, default: 0 },
      goalsWorkedOn: { type: Number, default: 0 },
      strongestGoalTitle: { type: String },
      weakestGoalTitle: { type: String },
      minutesInvested: { type: Number, default: 0 },
    },
    wentWell: { type: String, maxlength: 1000 },
    wasDifficult: { type: String, maxlength: 1000 },
    improveNext: { type: String, maxlength: 1000 },
    submittedAt: { type: Date },
  },
  { timestamps: true },
);

reflectionSchema.index({ user: 1, weekStart: 1 }, { unique: true });

reflectionSchema.set('toJSON', jsonOptions());

export const WeeklyReflection = model<IWeeklyReflection>(
  'WeeklyReflection',
  reflectionSchema,
);
