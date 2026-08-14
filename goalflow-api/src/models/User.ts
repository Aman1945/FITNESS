import { Schema, model, Document, Types } from 'mongoose';
import {
  PROGRESS_STYLES,
  ProgressStyle,
  TIME_OF_DAY,
  TimeOfDay,
} from './enums';
import { jsonOptions } from './toJSON';

export interface IUserPreferences {
  /** 0 = Sunday ... 6 = Saturday */
  preferredDays: number[];
  preferredTimeOfDay: TimeOfDay;
  /** "HH:mm" in the user's own timezone */
  preferredStartTime: string;
  defaultSessionMinutes: number;
  weeklyTargetActions: number;
  progressStyle: ProgressStyle;
  constraints: string[];
}

export interface INotificationPreference {
  pushEnabled: boolean;
  emailEnabled: boolean;
  actionReminders: { enabled: boolean; minutesBefore: number };
  dailySummary: { enabled: boolean; time: string };
  weeklyDigest: { enabled: boolean; weekday: number; time: string };
  milestoneAlerts: boolean;
  quietHours: { enabled: boolean; start: string; end: string };
}

export interface IRefreshToken {
  tokenHash: string;
  expiresAt: Date;
  createdAt: Date;
  device?: string;
}

export interface IDeviceToken {
  token: string;
  platform: 'android' | 'ios' | 'web';
  createdAt: Date;
}

export interface IUser extends Document {
  _id: Types.ObjectId;
  name: string;
  email: string;
  passwordHash?: string;
  googleId?: string;
  avatarUrl?: string;
  mainObjective?: string;
  timezone: string;
  emailVerifiedAt?: Date;
  emailVerification?: { codeHash: string; expiresAt: Date; attempts: number };
  passwordReset?: { tokenHash: string; expiresAt: Date };
  onboardingCompleted: boolean;
  preferences: IUserPreferences;
  notificationPreference: INotificationPreference;
  refreshTokens: IRefreshToken[];
  deviceTokens: IDeviceToken[];
  lastActiveAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const preferencesSchema = new Schema<IUserPreferences>(
  {
    preferredDays: { type: [Number], default: [1, 2, 3, 4, 5] },
    preferredTimeOfDay: { type: String, enum: TIME_OF_DAY, default: 'evening' },
    preferredStartTime: { type: String, default: '19:00' },
    defaultSessionMinutes: { type: Number, default: 30, min: 5, max: 480 },
    weeklyTargetActions: { type: Number, default: 5, min: 1, max: 70 },
    progressStyle: { type: String, enum: PROGRESS_STYLES, default: 'percentage' },
    constraints: { type: [String], default: [] },
  },
  { _id: false },
);

const notificationPreferenceSchema = new Schema<INotificationPreference>(
  {
    pushEnabled: { type: Boolean, default: true },
    emailEnabled: { type: Boolean, default: true },
    actionReminders: {
      enabled: { type: Boolean, default: true },
      minutesBefore: { type: Number, default: 15, min: 0, max: 1440 },
    },
    dailySummary: {
      enabled: { type: Boolean, default: true },
      time: { type: String, default: '08:00' },
    },
    weeklyDigest: {
      enabled: { type: Boolean, default: true },
      weekday: { type: Number, default: 0, min: 0, max: 6 }, // Sunday
      time: { type: String, default: '19:00' },
    },
    milestoneAlerts: { type: Boolean, default: true },
    quietHours: {
      enabled: { type: Boolean, default: true },
      start: { type: String, default: '22:00' },
      end: { type: String, default: '07:00' },
    },
  },
  { _id: false },
);

const userSchema = new Schema<IUser>(
  {
    name: { type: String, required: true, trim: true, maxlength: 80 },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    // Never returned by default -- must be explicitly selected.
    passwordHash: { type: String, select: false },
    googleId: { type: String, sparse: true },
    avatarUrl: { type: String },
    mainObjective: { type: String, maxlength: 200 },
    timezone: { type: String, default: 'Asia/Kolkata' },
    emailVerifiedAt: { type: Date },
    emailVerification: {
      type: new Schema(
        {
          codeHash: String,
          expiresAt: Date,
          attempts: { type: Number, default: 0 },
        },
        { _id: false },
      ),
      select: false,
    },
    passwordReset: {
      type: new Schema({ tokenHash: String, expiresAt: Date }, { _id: false }),
      select: false,
    },
    onboardingCompleted: { type: Boolean, default: false },
    preferences: { type: preferencesSchema, default: () => ({}) },
    notificationPreference: { type: notificationPreferenceSchema, default: () => ({}) },
    refreshTokens: { type: [Object], default: [], select: false },
    deviceTokens: {
      type: [
        new Schema(
          {
            token: { type: String, required: true },
            platform: { type: String, enum: ['android', 'ios', 'web'], default: 'android' },
            createdAt: { type: Date, default: Date.now },
          },
          { _id: false },
        ),
      ],
      default: [],
    },
    lastActiveAt: { type: Date },
  },
  { timestamps: true },
);

userSchema.set('toJSON', jsonOptions(['passwordHash', 'refreshTokens', 'emailVerification', 'passwordReset']));

export const User = model<IUser>('User', userSchema);
