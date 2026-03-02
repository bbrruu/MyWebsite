import { useState } from 'react';
import type { Member } from './types';

interface Props {
  members: Member[];
  onAdd: (name: string) => void;
  onRemove: (id: string) => void;
  onNext: () => void;
}

export default function MembersStep({ members, onAdd, onRemove, onNext }: Props) {
  const [input, setInput] = useState('');
  const [error, setError] = useState('');

  function handleAdd() {
    const name = input.trim();
    if (!name) return;
    if (members.some(m => m.name === name)) {
      setError('已有同名成員');
      return;
    }
    onAdd(name);
    setInput('');
    setError('');
  }

  return (
    <div className="sp-members-step">
      <p className="sp-step-desc">輸入出遊成員的名字，按 Enter 或點「新增」加入</p>

      <form className="sp-members-input-row" onSubmit={e => { e.preventDefault(); handleAdd(); }}>
        <input
          className="sp-input"
          type="text"
          placeholder="成員名稱"
          value={input}
          onChange={e => { setInput(e.target.value); setError(''); }}
          maxLength={20}
        />
        <button type="submit" className="sp-btn-primary">新增</button>
      </form>
      {error && <p className="sp-error">{error}</p>}

      <div className="sp-members-list">
        {members.length === 0 && (
          <p className="sp-empty">還沒有成員，請先新增</p>
        )}
        {members.map(m => (
          <div key={m.id} className="sp-member-tag" style={{ borderColor: m.color }}>
            <span className="sp-member-dot" style={{ background: m.color }} />
            <span className="sp-member-name">{m.name}</span>
            <button
              className="sp-member-remove"
              onClick={() => onRemove(m.id)}
              title="移除"
            >×</button>
          </div>
        ))}
      </div>

      <div className="sp-step-nav">
        <button
          className="sp-btn-primary"
          onClick={onNext}
          disabled={members.length < 2}
        >
          下一步：記錄帳目 →
        </button>
        {members.length < 2 && (
          <p className="sp-hint">至少需要 2 位成員</p>
        )}
      </div>
    </div>
  );
}
