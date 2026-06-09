import type { UseQueryResult } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import { Alert, Box, Button, CircularProgress } from '@mui/material'

interface Props<T> {
  query: UseQueryResult<T>
  children: (data: T) => ReactNode
}

/** Renders a query: spinner while loading, an error + retry on failure. */
export default function QueryBoundary<T>({ query, children }: Props<T>) {
  if (query.isPending) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', p: 6 }}>
        <CircularProgress />
      </Box>
    )
  }
  if (query.isError) {
    return (
      <Box sx={{ p: 1 }}>
        <Alert
          severity="error"
          action={
            <Button color="inherit" size="small" onClick={() => void query.refetch()}>
              Retry
            </Button>
          }
        >
          {query.error instanceof Error ? query.error.message : 'Something went wrong.'}
        </Alert>
      </Box>
    )
  }
  return <>{children(query.data as T)}</>
}
