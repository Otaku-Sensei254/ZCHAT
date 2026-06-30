import { useState, useEffect } from "react";
import { useParams, Link } from "react-router-dom";
import api from "../../utils/api";

export default function ConfirmEmail() {
  const { token } = useParams();
  const [status, setStatus] = useState("loading");

  useEffect(() => {
    api.post("/auth/confirm-email", { token }).then(() => {
      setStatus("success");
    }).catch(() => {
      setStatus("error");
    });
  }, [token]);

  return (
    <div className="min-h-[calc(100vh-56px)] flex items-center justify-center px-3 sm:px-4 bg-gradient-to-br from-tide-50/50 via-white to-flow-50/50 dark:from-gray-900 dark:via-gray-800 dark:to-gray-900">
      <div className="w-full max-w-sm bg-white dark:bg-gray-800/80 rounded-2xl border border-gray-100 dark:border-gray-700/60 shadow-sm p-6 sm:p-7 text-center">
        {status === "loading" && (
          <>
            <div className="animate-spin rounded-full h-8 w-8 border-[3px] border-tide-500 border-t-transparent mx-auto mb-4" />
            <p className="text-gray-500">Confirming your email...</p>
          </>
        )}
        {status === "success" && (
          <>
            <div className="w-14 h-14 bg-green-100 dark:bg-green-900/30 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-7 h-7 text-green-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" /></svg>
            </div>
            <h2 className="text-lg font-bold mb-2">Email Confirmed!</h2>
            <p className="text-sm text-gray-500 mb-4">Your email has been verified.</p>
            <Link to="/login" className="text-tide-600 hover:underline text-sm font-medium">Sign in</Link>
          </>
        )}
        {status === "error" && (
          <>
            <div className="w-14 h-14 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center mx-auto mb-4">
              <svg className="w-7 h-7 text-red-600" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" /></svg>
            </div>
            <h2 className="text-lg font-bold mb-2">Invalid Link</h2>
            <p className="text-sm text-gray-500 mb-4">This confirmation link is invalid or expired.</p>
            <Link to="/login" className="text-tide-600 hover:underline text-sm font-medium">Sign in</Link>
          </>
        )}
      </div>
    </div>
  );
}