/**
 * Starter breakdowns per category.
 * A brand-new goal arrives with a sensible Milestone/Action structure instead of an
 * empty screen -- the user edits rather than invents. Everything here is editable,
 * nothing is enforced.
 */
export interface GoalTemplate {
  label: string;
  milestones: { title: string; actions: string[] }[];
}

export const GOAL_TEMPLATES: Record<string, GoalTemplate> = {
  health: {
    label: 'Build a fitness habit',
    milestones: [
      {
        title: 'Build the base',
        actions: ['Warm up and stretch', '30 minute workout', 'Log how it felt'],
      },
      {
        title: 'Increase intensity',
        actions: ['Strength session', 'Cardio session', 'Rest and recovery check'],
      },
    ],
  },
  learning: {
    label: 'Learn something new',
    milestones: [
      {
        title: 'Build the fundamentals',
        actions: ['Complete one lesson', 'Practise for 20 minutes', 'Review yesterday'],
      },
      {
        title: 'Apply it',
        actions: ['Build a small exercise', 'Teach it back in your own words'],
      },
    ],
  },
  career: {
    label: 'Move your career forward',
    milestones: [
      {
        title: 'Sharpen the craft',
        actions: ['Deep work block', 'Read one industry piece'],
      },
      {
        title: 'Get visible',
        actions: ['Update portfolio or CV', 'Reach out to one person'],
      },
    ],
  },
  finance: {
    label: 'Get finances in order',
    milestones: [
      { title: 'See the picture', actions: ['Log this week\'s spending', 'Review subscriptions'] },
      { title: 'Build the buffer', actions: ['Move money to savings', 'Review the budget'] },
    ],
  },
  personal: {
    label: 'A personal goal',
    milestones: [
      { title: 'Get started', actions: ['Spend focused time on it', 'Note what worked'] },
      { title: 'Keep it going', actions: ['Weekly review', 'Adjust the routine'] },
    ],
  },
  relationships: {
    label: 'Invest in people',
    milestones: [
      { title: 'Stay in touch', actions: ['Message someone you value', 'Plan time together'] },
    ],
  },
  productivity: {
    label: 'Work with more focus',
    milestones: [
      { title: 'Protect focus', actions: ['One deep work block', 'Plan tomorrow in 5 minutes'] },
    ],
  },
  custom: {
    label: 'Your own goal',
    milestones: [{ title: 'First steps', actions: ['Work on it for one session'] }],
  },
};
