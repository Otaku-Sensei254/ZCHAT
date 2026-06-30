export default function CreateCurrent() {
  return (
    <div className="max-w-2xl mx-auto px-4 py-8">
      <div className="text-center mt-20">
        <div className="w-20 h-20 mx-auto rounded-2xl bg-gradient-to-br from-tide-500 to-flow-600 flex items-center justify-center mb-6 shadow-lg shadow-tide-200 dark:shadow-tide-900/30">
          <svg className="w-10 h-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
          </svg>
        </div>
        <h1 className="text-3xl font-bold text-gray-900 dark:text-white mb-3">Create a Current</h1>
        <p className="text-gray-500 dark:text-gray-400 max-w-md mx-auto mb-6">
          Upload a short-form video — coming soon.
        </p>
      </div>
    </div>
  );
}
