import type { Step } from './types';

const STEPS: { key: Step; label: string }[] = [
  { key: 'members',    label: '① 成員' },
  { key: 'expenses',   label: '② 帳目' },
  { key: 'settlement', label: '③ 結算' },
];

interface Props {
  current: Step;
  onNavigate: (step: Step) => void;
  membersOk: boolean;
  expensesOk: boolean;
}

export default function StepIndicator({ current, onNavigate, membersOk, expensesOk }: Props) {
  function canNavigate(key: Step): boolean {
    if (key === 'members') return true;
    if (key === 'expenses') return membersOk;
    if (key === 'settlement') return membersOk && expensesOk;
    return false;
  }

  return (
    <div className="sp-step-indicator">
      {STEPS.map((s, i) => (
        <div key={s.key} className="sp-step-row">
          {i > 0 && <div className="sp-step-connector" />}
          <button
            className={`sp-step-btn${current === s.key ? ' active' : ''}${!canNavigate(s.key) ? ' disabled' : ''}`}
            onClick={() => canNavigate(s.key) && onNavigate(s.key)}
            disabled={!canNavigate(s.key)}
          >
            {s.label}
          </button>
        </div>
      ))}
    </div>
  );
}
