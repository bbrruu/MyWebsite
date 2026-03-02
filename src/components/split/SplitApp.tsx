import { useState } from 'react';
import { useSplitState } from './useSplitState';
import StepIndicator from './StepIndicator';
import MembersStep from './MembersStep';
import ExpensesStep from './ExpensesStep';
import SettlementStep from './SettlementStep';

export default function SplitApp() {
  const {
    members, expenses, step, settlement, balances,
    addMember, removeMember, addExpense, removeExpense, setStep, reset,
  } = useSplitState();

  const [showConfirm, setShowConfirm] = useState(false);

  function handleReset() {
    reset();
    setShowConfirm(false);
  }

  return (
    <div className="sp-app">
      {/* Reset button */}
      <button
        className="sp-reset-btn"
        onClick={() => setShowConfirm(true)}
        title="清空重置"
      >
        🗑
      </button>

      <StepIndicator
        current={step}
        onNavigate={setStep}
        membersOk={members.length >= 2}
        expensesOk={expenses.length > 0}
      />

      <div className="sp-step-content">
        {step === 'members' && (
          <MembersStep
            members={members}
            onAdd={addMember}
            onRemove={removeMember}
            onNext={() => setStep('expenses')}
          />
        )}
        {step === 'expenses' && (
          <ExpensesStep
            members={members}
            expenses={expenses}
            onAdd={addExpense}
            onRemove={removeExpense}
            onBack={() => setStep('members')}
            onNext={() => setStep('settlement')}
          />
        )}
        {step === 'settlement' && (
          <SettlementStep
            members={members}
            balances={balances}
            settlement={settlement}
            onBack={() => setStep('expenses')}
          />
        )}
      </div>

      {/* Confirm modal */}
      {showConfirm && (
        <div className="sp-confirm-overlay" onClick={() => setShowConfirm(false)}>
          <div className="sp-confirm-dialog" onClick={e => e.stopPropagation()}>
            <p className="sp-confirm-msg">確定要清空所有帳目嗎？<br />此操作無法復原。</p>
            <div className="sp-confirm-actions">
              <button className="sp-btn-ghost" onClick={() => setShowConfirm(false)}>取消</button>
              <button className="sp-btn-danger" onClick={handleReset}>確定清空</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
