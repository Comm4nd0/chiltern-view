import { useState } from 'react'
import {
  Box,
  Button,
  Card,
  CardContent,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  List,
  ListItem,
  ListItemText,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useEggSummary, useEggTrend, useIncrementEggs, useRecentEggs } from '../api/hooks'
import QueryBoundary from '../components/QueryBoundary'
import MiniBarChart from '../components/MiniBarChart'
import { fmtDate } from '../format'

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <Card sx={{ flex: 1 }}>
      <CardContent sx={{ textAlign: 'center', py: 1.5 }}>
        <Typography variant="h6">{value}</Typography>
        <Typography variant="caption" color="text.secondary">
          {label}
        </Typography>
      </CardContent>
    </Card>
  )
}

export default function EggLogPage() {
  const summary = useEggSummary()
  const trend = useEggTrend(30)
  const recent = useRecentEggs()
  const increment = useIncrementEggs()
  const [customOpen, setCustomOpen] = useState(false)
  const [custom, setCustom] = useState('')

  const add = (count: number) => increment.mutate({ count })
  const today = summary.data?.today ?? 0

  return (
    <Stack spacing={2}>
      <Card sx={{ bgcolor: 'primary.main', color: 'primary.contrastText' }}>
        <CardContent sx={{ textAlign: 'center' }}>
          <Typography variant="overline">Collected today</Typography>
          <Typography variant="h2" fontWeight={700}>
            {today}
          </Typography>
          <Button
            fullWidth
            variant="contained"
            color="inherit"
            sx={{ color: 'primary.main', mt: 1 }}
            onClick={() => add(1)}
            disabled={increment.isPending}
          >
            + Add one egg
          </Button>
          <Stack
            direction="row"
            spacing={1}
            justifyContent="center"
            sx={{ mt: 1, flexWrap: 'wrap', rowGap: 1 }}
          >
            {[2, 4, 6, 12].map((n) => (
              <Button
                key={n}
                size="small"
                variant="outlined"
                color="inherit"
                onClick={() => add(n)}
                disabled={increment.isPending}
              >
                +{n}
              </Button>
            ))}
            <Button size="small" variant="outlined" color="inherit" onClick={() => setCustomOpen(true)}>
              Custom
            </Button>
          </Stack>
        </CardContent>
      </Card>

      <QueryBoundary query={summary}>
        {(s) => (
          <Stack direction="row" spacing={1}>
            <Stat label="This week" value={s.this_week} />
            <Stat label="This month" value={s.this_month} />
            <Stat label="All time" value={s.total} />
          </Stack>
        )}
      </QueryBoundary>

      <QueryBoundary query={trend}>
        {(t) =>
          t.total === 0 ? null : (
            <Card>
              <CardContent sx={{ py: 1.5 }}>
                <Stack direction="row" justifyContent="space-between" alignItems="baseline">
                  <Typography variant="subtitle2">Last 30 days</Typography>
                  <Typography variant="caption" color="text.secondary">
                    {t.average}/day avg · {t.total} total
                  </Typography>
                </Stack>
                <Box sx={{ mt: 1 }}>
                  <MiniBarChart data={t.days} />
                </Box>
              </CardContent>
            </Card>
          )
        }
      </QueryBoundary>

      <Typography variant="subtitle1">Recent</Typography>
      <QueryBoundary query={recent}>
        {(records) =>
          records.length === 0 ? (
            <Typography color="text.secondary">No eggs logged yet.</Typography>
          ) : (
            <List disablePadding>
              {records.map((r) => (
                <Card key={r.id} sx={{ mb: 1 }}>
                  <ListItem secondaryAction={<Typography variant="h6">{r.count}</Typography>}>
                    <ListItemText
                      primary={fmtDate(r.date, {
                        weekday: 'short',
                        day: 'numeric',
                        month: 'short',
                        year: 'numeric',
                      })}
                      secondary={r.source || undefined}
                    />
                  </ListItem>
                </Card>
              ))}
            </List>
          )
        }
      </QueryBoundary>

      {customOpen && (
        <Dialog open onClose={() => setCustomOpen(false)}>
          <DialogTitle>Add eggs</DialogTitle>
          <DialogContent>
            <TextField
              autoFocus
              type="number"
              label="How many?"
              value={custom}
              onChange={(e) => setCustom(e.target.value)}
              sx={{ mt: 1 }}
            />
          </DialogContent>
          <DialogActions>
            <Button onClick={() => setCustomOpen(false)}>Cancel</Button>
            <Button
              variant="contained"
              onClick={() => {
                const n = Number(custom)
                if (n > 0) add(n)
                setCustom('')
                setCustomOpen(false)
              }}
            >
              Add
            </Button>
          </DialogActions>
        </Dialog>
      )}
    </Stack>
  )
}
