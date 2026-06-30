export default function Currents() {
  return (
    <div className="max-w-4xl mx-auto px-4 py-8">
      <div className="text-center mt-20">
        <div className="w-20 h-20 mx-auto rounded-2xl bg-gradient-to-br from-tide-500 to-flow-600 flex items-center justify-center mb-6 shadow-lg shadow-tide-200 dark:shadow-tide-900/30">
          <svg className="w-10 h-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-3">Currents</h1>
        <p className="text-gray-500 dark:text-gray-400 max-w-md mx-auto">
          Short-form videos — coming soon. This is your space for reels, clips, and quick stories.
        </p>
      </div>
    </div>
  );
}
