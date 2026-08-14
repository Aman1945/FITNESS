export const GOAL_CATEGORIES = [
  'health',
  'learning',
  'career',
  'personal',
  'finance',
  'relationships',
  'productivity',
  'custom',
] as const;
export type GoalCategory = (typeof GOAL_CATEGORIES)[number];

export const PRIORITIES = ['low', 'medium', 'high'] as const;
export type Priority = (typeof PRIORITIES)[number];

export const GOAL_STATUSES = ['active', 'paused', 'completed', 'archived'] as const;
export type GoalStatus = (typeof GOAL_STATUSES)[number];

/** Derived, never set by the client. See goals/goal.status.service.ts */
export const PROGRESS_STATUSES = [
  'ahead',
  'on_track',
  'needs_attention',
  'behind',
  'completed',
] as const;
export type ProgressStatus = (typeof PROGRESS_STATUSES)[number];

export const MILESTONE_STATUSES = ['pending', 'in_progress', 'completed'] as const;
export type MilestoneStatus = (typeof MILESTONE_STATUSES)[number];

export const OCCURRENCE_STATUSES = [
  'upcoming',
  'in_progress',
  'completed',
  'missed',
  'skipped',
] as const;
export type OccurrenceStatus = (typeof OCCURRENCE_STATUSES)[number];

export const FREQUENCY_TYPES = ['daily', 'specific_days', 'weekly_count', 'once'] as const;
export type FrequencyType = (typeof FREQUENCY_TYPES)[number];

export const TIME_OF_DAY = ['morning', 'afternoon', 'evening', 'night'] as const;
export type TimeOfDay = (typeof TIME_OF_DAY)[number];

export const DIFFICULTIES = ['easy', 'medium', 'hard'] as const;
export type Difficulty = (typeof DIFFICULTIES)[number];

export const PROGRESS_STYLES = ['percentage', 'streak', 'minimal'] as const;
export type ProgressStyle = (typeof PROGRESS_STYLES)[number];

export const NOTIFICATION_TYPES = [
  'action_reminder',
  'daily_summary',
  'weekly_digest',
  'milestone',
  'goal_status',
  'system',
] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

/** Default window used when a user has not picked an explicit start time. */
export const TIME_OF_DAY_DEFAULTS: Record<TimeOfDay, string> = {
  morning: '07:00',
  afternoon: '13:00',
  evening: '19:00',
  night: '21:30',
};
