import { useState, useRef, useEffect, useCallback } from "react";
import { FiChevronLeft, FiChevronRight } from "react-icons/fi";

function VideoSlide({ src, isVisible }) {
  const videoRef = useRef(null);
  const observerRef = useRef(null);

  useEffect(() => {
    const el = videoRef.current;
    if (!el) return;

    observerRef.current = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting && isVisible) {
          el.play().catch(() => {});
        } else {
          el.pause();
        }
      },
      { threshold: 0.5 }
    );
    observerRef.current.observe(el);

    return () => observerRef.current?.disconnect();
  }, [isVisible]);

  return (
    <video
      ref={videoRef}
      src={src}
      muted
      loop
      playsInline
      controls
      preload="metadata"
      className="w-full max-h-[32rem] object-contain bg-black/5 dark:bg-black/20"
    />
  );
}

export default function MediaCarousel({ files }) {
  const [current, setCurrent] = useState(0);
  const [showArrows, setShowArrows] = useState(false);
  const touchStart = useRef(null);

  const prev = useCallback(() => {
    setCurrent((c) => (c > 0 ? c - 1 : files.length - 1));
  }, [files.length]);

  const next = useCallback(() => {
    setCurrent((c) => (c < files.length - 1 ? c + 1 : 0));
  }, [files.length]);

  const onTouchStart = (e) => {
    touchStart.current = { x: e.touches[0].clientX, y: e.touches[0].clientY };
  };

  const onTouchEnd = (e) => {
    if (!touchStart.current) return;
    const dx = e.changedTouches[0].clientX - touchStart.current.x;
    const dy = e.changedTouches[0].clientY - touchStart.current.y;
    if (Math.abs(dx) > Math.abs(dy) && Math.abs(dx) > 50) {
      if (dx > 0) prev();
      else next();
    }
    touchStart.current = null;
  };

  const hasMultiple = files.length > 1;

  return (
    <div
      className="relative rounded-xl overflow-hidden bg-black/5 dark:bg-black/20 select-none"
      onMouseEnter={() => setShowArrows(true)}
      onMouseLeave={() => setShowArrows(false)}
      onTouchStart={onTouchStart}
      onTouchEnd={onTouchEnd}
    >
      <div
        className="flex transition-transform duration-300 ease-out"
        style={{ transform: `translateX(-${current * 100}%)` }}
      >
        {files.map((file, i) => (
          <div key={i} className="min-w-0 w-full shrink-0">
            {file.type === "video" ? (
              <VideoSlide src={file.url} isVisible={i === current} />
            ) : (
              <img
                src={file.url}
                alt=""
                className="w-full max-h-[32rem] object-contain bg-black/5 dark:bg-black/20"
                draggable={false}
              />
            )}
          </div>
        ))}
      </div>

      {hasMultiple && (
        <>
          <button
            onClick={prev}
            className={`absolute left-2 top-1/2 -translate-y-1/2 w-8 h-8 rounded-full bg-white/80 dark:bg-gray-900/80 text-gray-700 dark:text-gray-300 flex items-center justify-center shadow-md hover:bg-white dark:hover:bg-gray-900 transition-all duration-200 ${
              showArrows ? "opacity-100" : "opacity-0"
            }`}
          >
            <FiChevronLeft size={18} />
          </button>
          <button
            onClick={next}
            className={`absolute right-2 top-1/2 -translate-y-1/2 w-8 h-8 rounded-full bg-white/80 dark:bg-gray-900/80 text-gray-700 dark:text-gray-300 flex items-center justify-center shadow-md hover:bg-white dark:hover:bg-gray-900 transition-all duration-200 ${
              showArrows ? "opacity-100" : "opacity-0"
            }`}
          >
            <FiChevronRight size={18} />
          </button>
        </>
      )}

      {hasMultiple && (
        <div className="absolute bottom-2 left-1/2 -translate-x-1/2 flex gap-1.5">
          {files.map((_, i) => (
            <button
              key={i}
              onClick={() => setCurrent(i)}
              className={`w-2 h-2 rounded-full transition-all duration-200 ${
                i === current
                  ? "bg-white w-4 shadow-md"
                  : "bg-white/60 hover:bg-white/80"
              }`}
            />
          ))}
        </div>
      )}

      {hasMultiple && (
        <div className="absolute top-2 right-2 px-2 py-0.5 rounded-full bg-black/50 text-white text-xs font-medium">
          {current + 1}/{files.length}
        </div>
      )}
    </div>
  );
}