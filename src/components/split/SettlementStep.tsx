import { useState } from 'react';
import type { Member, Transaction } from './types';

interface Props {
  members: Member[];
  balances: Map<string, number>;
  settlement: Transaction[];
  onBack: () => void;
}

export default function SettlementStep({ members, balances, settlement, onBack }: Props) {
  const [copied, setCopied] = useState(false);

  function getMember(id: string) {
    return members.find(m => m.id === id);
  }

  function handleCopy() {
    if (settlement.length === 0) {
      navigator.clipboard.writeText('大家都平了！不需要任何轉帳 🎉').then(() => {
        setCopied(true);
        setTimeout(() => setCopied(false), 2000);
      });
      return;
    }
    const lines = settlement.map(
      t => `${getMember(t.from)?.name} 付給 ${getMember(t.to)?.name}　NT$${t.amount.toLocaleString()}`
    );
    navigator.clipboard.writeText(lines.join('\n')).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    });
  }

  const allEven = settlement.length === 0;

  return (
    <div className="sp-settlement-step">

      {/* Balance overview */}
      <div className="sp-settlement-balances">
        <h3 className="sp-settlement-subtitle">各人淨餘額</h3>
        <div className="sp-balance-list">
          {members.map(m => {
            const bal = Math.round((balances.get(m.id) ?? 0) * 100) / 100;
            const positive = bal > 0.005;
            const negative = bal < -0.005;
            return (
              <div key={m.id} className="sp-balance-row">
                <span className="sp-member-dot" style={{ background: m.color }} />
                <span className="sp-balance-name">{m.name}</span>
                <span className={`sp-balance-amount${positive ? ' sp-positive' : negative ? ' sp-negative' : ''}`}>
                  {positive ? `+NT$${bal.toLocaleString()}` : negative ? `-NT$${Math.abs(bal).toLocaleString()}` : '平'}
                </span>
                <span className="sp-balance-desc">
                  {positive ? '（多付了）' : negative ? '（少付了）' : ''}
                </span>
              </div>
            );
          })}
        </div>
      </div>

      {/* Settlement transactions */}
      <div className="sp-settlement-result">
        <h3 className="sp-settlement-subtitle">結算清單</h3>
        {allEven ? (
          <p className="sp-all-even">大家都平了！不需要任何轉帳 🎉</p>
        ) : (
          <div className="sp-transaction-list">
            {settlement.map((t, i) => {
              const from = getMember(t.from);
              const to = getMember(t.to);
              return (
                <div key={i} className="sp-transaction-row">
                  <span className="sp-tx-from">
                    <span className="sp-member-dot" style={{ background: from?.color }} />
                    {from?.name}
                  </span>
                  <span className="sp-tx-arrow">→ 付給 →</span>
                  <span className="sp-tx-to">
                    <span className="sp-member-dot" style={{ background: to?.color }} />
                    {to?.name}
                  </span>
                  <span className="sp-tx-amount">NT${t.amount.toLocaleString()}</span>
                </div>
              );
            })}
          </div>
        )}
        <button className="sp-btn-copy" onClick={handleCopy}>
          {copied ? '已複製！' : '複製結算清單'}
        </button>
      </div>

      <div className="sp-step-nav">
        <button className="sp-btn-ghost" onClick={onBack}>← 返回帳目</button>
      </div>
    </div>
  );
}
