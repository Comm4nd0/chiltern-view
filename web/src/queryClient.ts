import { QueryClient } from '@tanstack/react-query'

// Single shared instance so non-component code (the API client) can clear all
// cached data on logout / 401 — preventing one user's data lingering for the
// next person who signs in on the same browser.
export const queryClient = new QueryClient({
  defaultOptions: { queries: { refetchOnWindowFocus: false, staleTime: 10_000 } },
})
