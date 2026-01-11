# Feedback Triage Service Plan

## Goal

Create a low-friction system where:
1. Users email bugs/suggestions to a dedicated address
2. Bugs are automatically triaged and fixed by Claude
3. Larger changes/features are sent to you for one-click approval
4. Minimal involvement from you except approving significant changes

---

## Recommended Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  User sends     │────▶│  Email received │────▶│  GitHub Issue   │
│  email          │     │  (forwarding)   │     │  created        │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                                                        │
                                                        ▼
                                              ┌─────────────────┐
                                              │  Claude triages │
                                              │  the issue      │
                                              └─────────────────┘
                                                        │
                                    ┌───────────────────┴───────────────────┐
                                    ▼                                       ▼
                          ┌─────────────────┐                     ┌─────────────────┐
                          │  BUG: Claude    │                     │  FEATURE: PR    │
                          │  fixes & merges │                     │  created for    │
                          │  automatically  │                     │  your approval  │
                          └─────────────────┘                     └─────────────────┘
                                                                          │
                                                                          ▼
                                                                ┌─────────────────┐
                                                                │  You get email  │
                                                                │  with approve/  │
                                                                │  reject links   │
                                                                └─────────────────┘
```

---

## Implementation Steps

### Step 1: Create Feedback Email Address

**Option A: Gmail (Free, Simple)**
- Create `scorekeeper.feedback@gmail.com` or similar
- Use Gmail filters to auto-label incoming mail
- Forward to GitHub Issues via Zapier/Make

**Option B: Custom Domain (Professional)**
- `feedback@scorekeeper.app` or similar
- Requires domain + email hosting (~$5-12/month)
- More professional appearance

**Recommendation:** Start with Gmail for simplicity, migrate later if needed.

### Step 2: Email → GitHub Issues Pipeline

**Option A: Zapier (Easiest)**
- Connect Gmail to GitHub
- Trigger: New email in Gmail
- Action: Create GitHub issue
- ~100 tasks/month free, then $20/month

**Option B: Make.com (Cheaper)**
- Similar to Zapier
- 1,000 ops/month free
- More complex setup

**Option C: GitHub Actions + Email Polling (Free but Complex)**
- Custom script polls email via IMAP
- Creates issues via GitHub API
- Runs on schedule (every 15 min)

**Recommendation:** Zapier for quick setup, migrate to Make.com or custom if volume increases.

### Step 3: Issue Template

When an email comes in, create an issue with this structure:

```markdown
## Feedback from User

**From:** [sender email - redacted for privacy]
**Date:** [timestamp]
**Subject:** [email subject]

---

### Message

[email body content]

---

### Triage Required

- [ ] Bug report
- [ ] Feature request
- [ ] Question/support
- [ ] Spam/invalid

Labels: `needs-triage`
```

### Step 4: Claude Triage Workflow

Use Claude Code with GitHub integration to:

1. **Monitor new issues** with `needs-triage` label
2. **Classify the issue:**
   - `bug` - Something broken that should work
   - `feature` - New functionality request
   - `enhancement` - Improvement to existing feature
   - `question` - User needs help
   - `invalid` - Spam or not actionable

3. **For bugs:**
   - Reproduce/understand the issue
   - Create fix on a branch
   - Run any tests
   - Auto-merge if fix is straightforward and safe
   - Comment on issue with what was fixed

4. **For features/enhancements:**
   - Create a PR with implementation
   - Add `needs-approval` label
   - Notify you for review

### Step 5: Your Approval Workflow

**GitHub PR Reviews (Recommended)**
- You receive email notification for PRs labeled `needs-approval`
- One-click "Approve" in GitHub UI or email
- Claude auto-merges after approval

**Simplified Email Approval (Alternative)**
- Set up GitHub Action that sends you email with:
  - Summary of proposed change
  - "Approve" link (triggers merge)
  - "Reject" link (closes PR with comment)

---

## Detailed Zapier Setup

### Zap 1: Email to Issue

```
Trigger: Gmail - New Email
  └─ Filter: To address contains "scorekeeper"

Action: GitHub - Create Issue
  └─ Repo: thomaspryor/scorekeeper
  └─ Title: [Feedback] {{subject}}
  └─ Body: (use template above)
  └─ Labels: needs-triage, user-feedback
```

### Zap 2: Approval Notification (Optional)

```
Trigger: GitHub - New Pull Request
  └─ Filter: Labels contain "needs-approval"

Action: Email - Send Email
  └─ To: your-email@example.com
  └─ Subject: [Scorekeeper] Approval needed: {{PR title}}
  └─ Body: Summary + approve/reject links
```

---

## Claude Code Configuration

### Repository Settings

Add a `.claude/settings.json` or similar configuration:

```json
{
  "feedback_triage": {
    "enabled": true,
    "auto_fix_bugs": true,
    "auto_merge_bug_fixes": true,
    "require_approval_for": [
      "new_features",
      "ui_changes",
      "breaking_changes",
      "dependency_updates"
    ],
    "owner_email": "your-email@example.com"
  }
}
```

### Triage Prompt Template

When Claude processes an issue:

```
You are triaging a user feedback issue for the Scorekeeper app.

Issue: {{issue_title}}
Content: {{issue_body}}

Tasks:
1. Classify as: bug, feature, enhancement, question, or invalid
2. For bugs: Investigate, fix, and create a PR
3. For features/enhancements: Create PR and request owner approval
4. For questions: Respond helpfully and close
5. For invalid: Close with polite explanation

Rules:
- Auto-merge bug fixes that are safe and well-tested
- Never auto-merge features, UI changes, or anything subjective
- Always explain what you did in issue comments
```

---

## Cost Estimate

| Component | Option | Cost |
|-----------|--------|------|
| Email | Gmail | Free |
| Email → Issues | Zapier | Free (100/mo) or $20/mo |
| GitHub | Public repo | Free |
| Claude Code | API usage | ~$5-20/mo depending on volume |
| **Total** | | **$0-40/month** |

---

## Security Considerations

1. **Email Privacy**
   - Don't expose sender emails in public issues
   - Hash or redact email addresses
   - Option: Make the repo private

2. **Spam Prevention**
   - Zapier/Make can filter obvious spam
   - Claude can close spam issues
   - Consider CAPTCHA if using a form instead

3. **Malicious Input**
   - Claude should never execute code from user input
   - Sanitize all input before display
   - Review any external URLs before clicking

4. **API Keys**
   - Store securely in Zapier/GitHub secrets
   - Never commit to repo

---

## Alternative: Google Form Instead of Email

If email parsing proves unreliable, use a Google Form:

**Pros:**
- Structured input (type: bug/feature, description, steps to reproduce)
- Built-in spam prevention
- Easier to parse

**Cons:**
- Slightly higher friction for users
- Less natural than email

**Form Fields:**
1. Type (dropdown): Bug / Feature Request / Question
2. Summary (short text)
3. Description (long text)
4. Steps to reproduce (long text, optional)
5. Email (optional, for follow-up)

---

## Implementation Timeline

### Phase 1: Basic Setup (Day 1)
- [ ] Create feedback email address
- [ ] Set up Zapier email → GitHub issue pipeline
- [ ] Test with sample emails

### Phase 2: Claude Integration (Day 2-3)
- [ ] Create triage workflow documentation
- [ ] Set up Claude Code access to repo
- [ ] Test bug fix workflow
- [ ] Test feature approval workflow

### Phase 3: Refinement (Week 1-2)
- [ ] Monitor and adjust triage rules
- [ ] Add issue templates for common cases
- [ ] Set up metrics/dashboard (optional)

### Phase 4: Documentation (Week 2)
- [ ] Add feedback instructions to app/README
- [ ] Create internal runbook for edge cases

---

## Getting Started

To implement this plan:

1. **Create the email:** Set up `scorekeeper.feedback@gmail.com`

2. **Connect Zapier:**
   - Sign up at zapier.com
   - Connect Gmail account
   - Connect GitHub account
   - Create the Zap as described above

3. **Add feedback link to app:** Add a "Send Feedback" option that opens:
   ```
   mailto:scorekeeper.feedback@gmail.com?subject=Scorekeeper%20Feedback
   ```

4. **Set up Claude monitoring:** Configure Claude Code to check for `needs-triage` issues periodically or on webhook trigger

5. **Test the flow:** Send test emails for bug, feature, and spam scenarios

---

## Questions to Decide

Before implementing, decide:

1. **Email address:** Gmail vs custom domain?
2. **Repo visibility:** Keep public or make private?
3. **Approval method:** GitHub PR review vs email links?
4. **Auto-merge scope:** Which bug fixes are safe to auto-merge?
5. **Response time SLA:** How quickly should bugs be addressed?

---

## Next Steps

Let me know your preferences on the questions above, and I can:
1. Set up the email forwarding rules
2. Create the Zapier integration
3. Add a feedback link to the Scorekeeper app
4. Configure the Claude triage workflow
