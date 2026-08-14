import { z } from 'zod';
import {
  FREQUENCY_TYPES,
  GOAL_CATEGORIES,
  GOAL_STATUSES,
  PRIORITIES,
  TIME_OF_DAY,
} from '../../models/enums';

const hhmm = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Use HH:mm (24h)');

export const routineSchema = z.object({
  type: z.enum(FREQUENCY_TYPES).default('specific_days'),
  days: z.array(z.number().int().min(0).max(6)).max(7).default([1, 3, 5]),
  timesPerWeek: z.number().int().min(1).max(7).default(3),
  timeOfDay: z.enum(TIME_OF_DAY).default('evening'),
  startTime: hhmm.default('19:00'),
  durationMinutes: z.number().int().min(5).max(480).default(30),
});

export const goalBody = z.object({
  title: z.string().min(2, 'Give your goal a name of at least 2 characters').max(120),
  description: z.string().max(1000).optional(),
  why: z.string().max(500).optional(),
  category: z.enum(GOAL_CATEGORIES).default('personal'),
  customCategory: z.string().max(40).optional(),
  priority: z.enum(PRIORITIES).default('medium'),
  startDate: z.coerce.date().default(() => new Date()),
  targetDate: z.coerce.date(),
  routine: routineSchema.default({}),
  // Stored hex. Rejected rather than accepted-and-ignored, because a malformed
  // colour used to reach the client and break rendering.
  color: z
    .string()
    .regex(/^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/, 'Colour must be a hex value like #5B5BD6')
    .optional(),
});

/** A custom category is meaningless without the name the user chose for it. */
const requireCustomCategoryName = (d: { category?: string; customCategory?: string }) =>
  d.category !== 'custom' || (d.customCategory?.trim().length ?? 0) >= 2;

const customCategoryError = {
  message: 'Give your custom category a name',
  path: ['customCategory'],
};

export const createGoalSchema = z.object({
  body: goalBody
    .refine((d) => d.targetDate > d.startDate, {
      message: 'Target date must be after the start date',
      path: ['targetDate'],
    })
    .refine(requireCustomCategoryName, customCategoryError),
});

export const updateGoalSchema = z.object({
  params: z.object({ id: z.string() }),
  body: goalBody.partial().extend({ status: z.enum(GOAL_STATUSES).optional() }),
});

export const listGoalsSchema = z.object({
  query: z.object({
    status: z.enum(GOAL_STATUSES).optional(),
    category: z.enum(GOAL_CATEGORIES).optional(),
    q: z.string().optional(),
  }),
});

export const idParam = z.object({ params: z.object({ id: z.string() }) });
