export function LoadingSkeleton() {
  return (
    <div className="track-grid">
      {[...Array(8)].map((_, i) => (
        <div key={i} className="track-card">
          <div className="skeleton skeleton-card" />
          <div className="skeleton skeleton-text" />
          <div className="skeleton skeleton-text" />
          <div className="skeleton skeleton-text" />
        </div>
      ))}
    </div>
  );
} 