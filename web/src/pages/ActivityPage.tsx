import { useNavigate } from 'react-router-dom'
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Divider,
  Stack,
  Typography,
} from '@mui/material'
import ArrowBackIcon from '@mui/icons-material/ArrowBack'
import { useActivityFeed } from '../api/hooks'
import { TYPE_COLORS } from '../journal'
import { fmtDate } from '../format'

/** Whole-holding "who did what" timeline: every journal note plus task
 * completions, newest first. */
export default function ActivityPage() {
  const navigate = useNavigate()
  const feed = useActivityFeed()
  const entries = feed.data?.pages.flatMap((p) => p.results) ?? []

  return (
    <Stack spacing={1}>
      <Stack direction="row" alignItems="center" spacing={1}>
        <Button startIcon={<ArrowBackIcon />} onClick={() => navigate(-1)}>
          Back
        </Button>
        <Typography variant="h6">Activity</Typography>
      </Stack>

      {feed.isPending ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 6 }}>
          <CircularProgress size={28} />
        </Box>
      ) : feed.isError ? (
        <Alert
          severity="error"
          action={
            <Button size="small" onClick={() => feed.refetch()}>
              Retry
            </Button>
          }
        >
          Couldn't load the activity feed.
        </Alert>
      ) : entries.length === 0 ? (
        <Typography color="text.secondary" sx={{ py: 4, textAlign: 'center' }}>
          Nothing has happened yet.
        </Typography>
      ) : (
        <>
          <Stack divider={<Divider />}>
            {entries.map((entry) => {
              const color = TYPE_COLORS[entry.entry_type] ?? '#8E8E93'
              const meta = [entry.animal_name, fmtDate(entry.occurred_on), entry.created_by_name]
                .filter(Boolean)
                .join(' · ')
              return (
                <Stack
                  key={entry.id}
                  direction="row"
                  spacing={1.5}
                  sx={{ py: 1.25, alignItems: 'flex-start', cursor: entry.animal ? 'pointer' : 'default' }}
                  onClick={() => entry.animal && navigate(`/animals/${entry.animal}`)}
                >
                  <Chip
                    label={entry.entry_type_display}
                    size="small"
                    sx={{ bgcolor: `${color}14`, color, fontWeight: 600, flexShrink: 0 }}
                  />
                  <Box sx={{ flex: 1, minWidth: 0 }}>
                    <Typography variant="body2" sx={{ whiteSpace: 'pre-wrap' }}>
                      {entry.note}
                    </Typography>
                    <Typography variant="caption" color="text.secondary">
                      {meta}
                    </Typography>
                  </Box>
                </Stack>
              )
            })}
          </Stack>
          {feed.hasNextPage && (
            <Box sx={{ textAlign: 'center', mt: 1 }}>
              <Button
                size="small"
                onClick={() => feed.fetchNextPage()}
                disabled={feed.isFetchingNextPage}
              >
                {feed.isFetchingNextPage ? 'Loading…' : 'Load more'}
              </Button>
            </Box>
          )}
        </>
      )}
    </Stack>
  )
}
