import { useState, useEffect } from 'react';
import type { Member, Expense, ExpenseSplit } from './types';

interface Props {
  members: Member[];
  onSubmit: (expense: Omit<Expense, 'id'>) => void;
  onCancel: () => void;
}

export default function ExpenseForm({ members, onSubmit, onCancel }: Props) {
  const [description, setDescription] = useState('');
  const [paidBy, setPaidBy] = useState(members[0]?.id ?? '');
  const [totalAmount, setTotalAmount] = useState('');
  const [splits, setSplits] = useState<Record<string, string>>(() => {
    const init: Record<string, string> = {};
    for (const m of members) init[m.id] = '';
    return init;
  });

  // When total changes, reset splits to empty (user fills manually or clicks even-split)
  useEffect(() => {
    setSplits(prev => {
      const next = { ...prev };
      return next;
    });
  }, []);

  const total = parseFloat(totalAmount) || 0;
  const splitSum = members.reduce((acc, m) => acc + (parseFloat(splits[m.id] ?? '') || 0), 0);
  const remaining = Math.round((total - splitSum) * 100) / 100;
  const isBalanced = total > 0 && Math.abs(remaining) < 0.01;

  function handleEvenSplit() {
    if (total <= 0) return;
    const each = Math.floor((total / members.length) * 100) / 100;
    const remainder = Math.round((total - each * members.length) * 100) / 100;
    const next: Record<string, string> = {};
    members.forEach((m, i) => {
      next[m.id] = i === 0
        ? String(Math.round((each + remainder) * 100) / 100)
        : String(each);
    });
    setSplits(next);
  }

  function handleSubmit() {
    if (!description.trim() || total <= 0 || !isBalanced) return;
    const splitList: ExpenseSplit[] = members.map(m => ({
      memberId: m.id,
      amount: parseFloat(splits[m.id] ?? '') || 0,
    }));
    onSubmit({ description: description.trim(), paidBy, totalAmount: total, splits: splitList });
    // Reset
    setDescription('');
    setPaidBy(members[0]?.id ?? '');
    setTotalAmount('');
    setSplits(Object.fromEntries(members.map(m => [m.id, ''])));
  }

  return (
    <div className="sp-expense-form">
      <div className="sp-form-row">
        <label className="sp-label">說明</label>
        <input
          className="sp-input sp-input-full"
          type="text"
          placeholder="例：晚餐、交通費"
          value={description}
          onChange={e => setDescription(e.target.value)}
          maxLength={40}
        />
      </div>

      <div className="sp-form-row sp-form-row-2">
        <div>
          <label className="sp-label">付款人</label>
          <div className="sp-select-wrapper">
            <select
              className="sp-select"
              value={paidBy}
              onChange={e => setPaidBy(e.target.value)}
            >
              {members.map(m => (
                <option key={m.id} value={m.id}>{m.name}</option>
              ))}
            </select>
            <span className="sp-select-arrow">↓</span>
          </div>
        </div>
        <div>
          <label className="sp-label">總金額（NT$）</label>
          <input
            className="sp-input sp-input-num"
            type="number"
            min="0"
            step="1"
            placeholder="0"
            value={totalAmount}
            onChange={e => setTotalAmount(e.target.value)}
          />
        </div>
      </div>

      <div className="sp-splits-section">
        <div className="sp-splits-header">
          <span className="sp-label">各人份額</span>
          <button className="sp-btn-ghost" onClick={handleEvenSplit} type="button">
            平均分攤
          </button>
        </div>
        <div className="sp-splits-grid">
          {members.map(m => (
            <div key={m.id} className="sp-split-row">
              <span className="sp-split-name">
                <span className="sp-member-dot" style={{ background: m.color }} />
                {m.name}
              </span>
              <input
                className="sp-input sp-input-num"
                type="number"
                min="0"
                step="1"
                placeholder="0"
                value={splits[m.id] ?? ''}
                onChange={e => setSplits(prev => ({ ...prev, [m.id]: e.target.value }))}
              />
            </div>
          ))}
        </div>
        <div className={`sp-split-summary${!isBalanced && total > 0 ? ' sp-split-error' : ''}`}>
          已分配 NT${splitSum.toLocaleString()} / 總計 NT${total.toLocaleString()}
          {!isBalanced && total > 0 && (
            <span> （差 NT${Math.abs(remaining).toLocaleString()}）</span>
          )}
        </div>
      </div>

      <div className="sp-form-actions">
        <button className="sp-btn-ghost" onClick={onCancel}>取消</button>
        <button
          className="sp-btn-primary"
          onClick={handleSubmit}
          disabled={!description.trim() || total <= 0 || !isBalanced}
        >
          新增帳目
        </button>
      </div>
    </div>
  );
}
