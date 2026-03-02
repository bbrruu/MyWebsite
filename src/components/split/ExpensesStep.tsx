import { useState } from 'react';
import type { Member, Expense } from './types';
import ExpenseForm from './ExpenseForm';

interface Props {
  members: Member[];
  expenses: Expense[];
  onAdd: (expense: Omit<Expense, 'id'>) => void;
  onRemove: (id: string) => void;
  onBack: () => void;
  onNext: () => void;
}

export default function ExpensesStep({ members, expenses, onAdd, onRemove, onBack, onNext }: Props) {
  const [showForm, setShowForm] = useState(false);
  const [expandedId, setExpandedId] = useState<string | null>(null);

  function getMember(id: string) {
    return members.find(m => m.id === id);
  }

  function handleAdd(expense: Omit<Expense, 'id'>) {
    onAdd(expense);
    setShowForm(false);
  }

  return (
    <div className="sp-expenses-step">
      <p className="sp-step-desc">記錄每筆帳目，並設定各人應付金額</p>

      {/* Expense list */}
      <div className="sp-expense-list">
        {expenses.length === 0 && (
          <p className="sp-empty">還沒有帳目，點「新增帳目」開始記錄</p>
        )}
        {expenses.map(e => {
          const payer = getMember(e.paidBy);
          const expanded = expandedId === e.id;
          return (
            <div key={e.id} className="sp-expense-card">
              <div
                className="sp-expense-summary"
                onClick={() => setExpandedId(expanded ? null : e.id)}
              >
                <div className="sp-expense-left">
                  <span className="sp-expense-desc">{e.description}</span>
                  <span className="sp-expense-payer">
                    <span
                      className="sp-member-dot"
                      style={{ background: payer?.color }}
                    />
                    {payer?.name} 付
                  </span>
                </div>
                <div className="sp-expense-right">
                  <span className="sp-expense-amount">NT${e.totalAmount.toLocaleString()}</span>
                  <button
                    className="sp-btn-remove"
                    onClick={ev => { ev.stopPropagation(); onRemove(e.id); }}
                    title="刪除"
                  >×</button>
                  <span className="sp-expense-toggle">{expanded ? '▲' : '▼'}</span>
                </div>
              </div>
              {expanded && (
                <div className="sp-expense-detail">
                  {e.splits.map(s => {
                    const m = getMember(s.memberId);
                    return (
                      <div key={s.memberId} className="sp-split-detail-row">
                        <span className="sp-member-dot" style={{ background: m?.color }} />
                        <span>{m?.name}</span>
                        <span className="sp-split-detail-amt">NT${s.amount.toLocaleString()}</span>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          );
        })}
      </div>

      {/* Add form toggle */}
      {!showForm ? (
        <button className="sp-btn-add" onClick={() => setShowForm(true)}>
          ＋ 新增帳目
        </button>
      ) : (
        <ExpenseForm
          members={members}
          onSubmit={handleAdd}
          onCancel={() => setShowForm(false)}
        />
      )}

      <div className="sp-step-nav sp-step-nav-2">
        <button className="sp-btn-ghost" onClick={onBack}>← 返回成員</button>
        <button
          className="sp-btn-primary"
          onClick={onNext}
          disabled={expenses.length === 0}
        >
          下一步：結算 →
        </button>
      </div>
      {expenses.length === 0 && (
        <p className="sp-hint">至少需要一筆帳目才能結算</p>
      )}
    </div>
  );
}
