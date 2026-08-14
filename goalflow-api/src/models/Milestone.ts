import { Schema, model, Document, Types } from 'mongoose';
import { MILESTONE_STATUSES, MilestoneStatus } from './enums';
import { jsonOptions } from './toJSON';

export interface IMilestone extends Document {
  _id: Types.ObjectId;
  user: Types.ObjectId;
  goal: Types.ObjectId;
  title: string;
  description?: string;
  order: number;
  targetDate?: Date;
  status: MilestoneStatus;
  progressPercent: number;
  completedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const milestoneSchema = new Schema<IMilestone>(
  {
    user: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    goal: { type: Schema.Types.ObjectId, ref: 'Goal', required: true, index: true },
    title: { type: String, required: true, trim: true, maxlength: 120 },
    description: { type: String, maxlength: 600 },
    order: { type: Number, default: 0 },
    targetDate: { type: Date },
    status: { type: String, enum: MILESTONE_STATUSES, default: 'pending' },
    progressPercent: { type: Number, default: 0, min: 0, max: 100 },
    completedAt: { type: Date },
  },
  { timestamps: true },
);

milestoneSchema.index({ goal: 1, order: 1 });

milestoneSchema.set('toJSON', jsonOptions());

export const Milestone = model<IMilestone>('Milestone', milestoneSchema);
