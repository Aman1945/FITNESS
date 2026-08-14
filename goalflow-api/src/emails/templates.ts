/**
 * Transactional email templates (Resend).
 * Plain template functions -- no JSX build step, and every client renders them.
 */

const BRAND = '#5B5BD6';
const INK = '#1A1A2E';
const MUTED = '#6B7280';

function layout(opts: { preheader: string; heading: string; body: string; cta?: { label: string; url: string } }): string {
  return `<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#F5F5F7;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <span style="display:none;opacity:0;color:transparent;height:0;width:0;overflow:hidden">${opts.preheader}</span>
  <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="background:#F5F5F7;padding:32px 16px;">
    <tr><td align="center">
      <table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="max-width:520px;background:#FFFFFF;border-radius:20px;overflow:hidden;box-shadow:0 2px 12px rgba(26,26,46,.06);">
        <tr><td style="padding:28px 32px 8px;">
          <div style="font-size:15px;font-weight:700;color:${BRAND};letter-spacing:-.2px;">GoalFlow</div>
        </td></tr>
        <tr><td style="padding:8px 32px 0;">
          <h1 style="margin:0 0 12px;font-size:24px;line-height:1.25;color:${INK};letter-spacing:-.4px;">${opts.heading}</h1>
          <div style="font-size:15px;line-height:1.6;color:${MUTED};">${opts.body}</div>
        </td></tr>
        ${
          opts.cta
            ? `<tr><td style="padding:24px 32px 8px;">
                 <a href="${opts.cta.url}" style="display:inline-block;background:${BRAND};color:#fff;text-decoration:none;font-size:15px;font-weight:600;padding:13px 26px;border-radius:12px;">${opts.cta.label}</a>
               </td></tr>`
            : ''
        }
        <tr><td style="padding:28px 32px 32px;">
          <hr style="border:none;border-top:1px solid #EDEDF2;margin:0 0 16px;">
          <div style="font-size:12px;line-height:1.6;color:#9CA3AF;">
            You're receiving this because you have a GoalFlow account.<br>
            Manage what we send you in Settings &rarr; Notification preferences.
          </div>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`;
}

export function verifyEmailTemplate(name: string, code: string) {
  return {
    subject: `${code} is your GoalFlow verification code`,
    html: layout({
      preheader: `Your code is ${code}`,
      heading: `Welcome, ${name}.`,
      body: `Enter this code in the app to verify your email and start setting up your goals.
        <div style="margin:20px 0;font-size:32px;font-weight:700;letter-spacing:8px;color:${INK};">${code}</div>
        <span style="font-size:13px;">This code expires in 10 minutes.</span>`,
    }),
  };
}

export function resetPasswordTemplate(name: string, resetUrl: string, token: string) {
  return {
    subject: 'Reset your GoalFlow password',
    html: layout({
      preheader: 'Reset your password',
      heading: `Hi ${name}, let's get you back in.`,
      body: `Tap the button below to choose a new password. The link expires in 15 minutes.
        <div style="margin:16px 0 0;font-size:12px;color:#9CA3AF;">If the button doesn't work, use this code in the app:
        <br><code style="font-size:13px;color:${INK};word-break:break-all;">${token}</code></div>
        <div style="margin:12px 0 0;font-size:13px;">Didn't request this? You can safely ignore this email.</div>`,
      cta: { label: 'Reset password', url: resetUrl },
    }),
  };
}

export interface DigestStats {
  planned: number;
  completed: number;
  missed: number;
  completionRate: number;
  strongest?: string;
  needsAttention?: string;
  minutesInvested: number;
}

export function weeklyDigestTemplate(name: string, stats: DigestStats, appUrl: string) {
  const row = (label: string, value: string) =>
    `<tr><td style="padding:7px 0;font-size:14px;color:${MUTED};">${label}</td>
     <td style="padding:7px 0;font-size:14px;font-weight:600;color:${INK};text-align:right;">${value}</td></tr>`;

  return {
    subject: `Your week: ${stats.completed} of ${stats.planned} actions done`,
    html: layout({
      preheader: `${stats.completionRate}% of your plan completed this week`,
      heading: `${name}, here's your week in 30 seconds.`,
      body: `<table width="100%" cellpadding="0" cellspacing="0" role="presentation" style="margin:8px 0 4px;">
          ${row('Planned', String(stats.planned))}
          ${row('Completed', String(stats.completed))}
          ${row('Missed', String(stats.missed))}
          ${row('Completion', `${stats.completionRate}%`)}
          ${row('Time invested', `${Math.round(stats.minutesInvested / 60)}h ${stats.minutesInvested % 60}m`)}
          ${stats.strongest ? row('Strongest', stats.strongest) : ''}
          ${stats.needsAttention ? row('Needs attention', stats.needsAttention) : ''}
        </table>
        <div style="margin-top:14px;font-size:14px;">Take a minute to reflect - it's the part that actually changes next week.</div>`,
      cta: { label: 'Write this week\'s reflection', url: appUrl },
    }),
  };
}

export function milestoneTemplate(name: string, milestoneTitle: string, goalTitle: string) {
  return {
    subject: `Milestone reached: ${milestoneTitle}`,
    html: layout({
      preheader: `You completed ${milestoneTitle}`,
      heading: 'Milestone reached.',
      body: `${name}, you just finished <strong style="color:${INK}">${milestoneTitle}</strong> on your goal
        <strong style="color:${INK}">${goalTitle}</strong>. That's real progress - not a streak number.`,
    }),
  };
}
