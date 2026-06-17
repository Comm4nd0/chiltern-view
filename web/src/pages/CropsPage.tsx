import { useState } from 'react'
import {
  Box,
  Card,
  CardContent,
  Chip,
  Divider,
  Fab,
  Snackbar,
  Stack,
  Typography,
} from '@mui/material'
import AddIcon from '@mui/icons-material/Add'
import { useCrops, useHarvestHistory } from '../api/hooks'
import QueryBoundary from '../components/QueryBoundary'
import CropCard from '../components/CropCard'
import AddCropDialog from '../components/AddCropDialog'
import HarvestDialog from '../components/HarvestDialog'
import type { Crop } from '../api/types'

export default function CropsPage() {
  const [view, setView] = useState<'growing' | 'previous'>('growing')
  // "Previous" needs every crop; the growing view uses the lighter default.
  const crops = useCrops(view === 'previous' ? 'all' : 'growing')
  // Server-side yield roll-up (per crop + overall total), shared with mobile.
  const harvests = useHarvestHistory()
  const [adding, setAdding] = useState(false)
  const [editing, setEditing] = useState<Crop | null>(null)
  const [harvesting, setHarvesting] = useState<Crop | null>(null)
  const [snack, setSnack] = useState<string | null>(null)

  return (
    <Box>
      <Stack direction="row" spacing={1} sx={{ pb: 1, mb: 1 }}>
        {(['growing', 'previous'] as const).map((v) => (
          <Chip
            key={v}
            label={v === 'growing' ? 'Growing' : 'Previous'}
            color={view === v ? 'primary' : 'default'}
            variant={view === v ? 'filled' : 'outlined'}
            onClick={() => setView(v)}
          />
        ))}
      </Stack>

      <QueryBoundary query={crops}>
        {(list) => {
          const shown =
            view === 'previous'
              ? list
                  .filter((c) => c.harvested_on != null)
                  .sort((a, b) => (b.harvested_on ?? '').localeCompare(a.harvested_on ?? ''))
              : list
          if (shown.length === 0) {
            return (
              <Typography align="center" color="text.secondary" sx={{ mt: 8 }}>
                {view === 'growing'
                  ? 'Nothing growing yet — add a crop.'
                  : 'No harvested crops yet.'}
              </Typography>
            )
          }
          const history = view === 'previous' ? (harvests.data?.by_crop ?? []) : []
          return (
            <Stack spacing={1}>
              {view === 'previous' && history.length > 0 && (
                <Card>
                  <CardContent>
                    <Stack direction="row" justifyContent="space-between" alignItems="baseline">
                      <Typography variant="subtitle1" fontWeight={600}>
                        Yield history
                      </Typography>
                      {(harvests.data?.total_kg ?? 0) > 0 && (
                        <Typography variant="subtitle2" color="text.secondary">
                          {Math.round((harvests.data?.total_kg ?? 0) * 100) / 100} kg total
                        </Typography>
                      )}
                    </Stack>
                    <Stack divider={<Divider flexItem />} spacing={1} sx={{ mt: 1 }}>
                      {history.map((row) => (
                        <Stack key={row.crop} direction="row" alignItems="baseline" spacing={1}>
                          <Box sx={{ flex: 1, minWidth: 0 }}>
                            <Typography variant="body2" fontWeight={600}>
                              {row.label}
                            </Typography>
                          </Box>
                          <Typography variant="body2" color="text.secondary">
                            {row.count} planting{row.count === 1 ? '' : 's'}
                          </Typography>
                          {row.total_kg > 0 && (
                            <Typography variant="body2" fontWeight={600}>
                              {Math.round(row.total_kg * 100) / 100} kg
                            </Typography>
                          )}
                        </Stack>
                      ))}
                    </Stack>
                  </CardContent>
                </Card>
              )}
              {shown.map((c) => (
                <CropCard
                  key={c.id}
                  crop={c}
                  onEdit={() => setEditing(c)}
                  onHarvest={() => setHarvesting(c)}
                />
              ))}
            </Stack>
          )
        }}
      </QueryBoundary>

      <Fab
        color="primary"
        sx={{
          position: 'fixed',
          bottom: 'calc(80px + env(safe-area-inset-bottom, 0px))',
          right: 24,
          zIndex: (t) => t.zIndex.appBar + 1,
        }}
        onClick={() => setAdding(true)}
        aria-label="Add crop"
      >
        <AddIcon />
      </Fab>
      {(adding || editing) && (
        <AddCropDialog
          crop={editing ?? undefined}
          onClose={() => {
            setAdding(false)
            setEditing(null)
          }}
        />
      )}
      {harvesting && (
        <HarvestDialog
          crop={harvesting}
          onClose={() => setHarvesting(null)}
          onDone={(c) =>
            setSnack(
              c.yield_kg != null
                ? `Harvested ${c.crop_label} — ${Number(c.yield_kg)} kg`
                : `Harvested ${c.crop_label}`,
            )
          }
        />
      )}
      <Snackbar
        open={snack != null}
        autoHideDuration={3000}
        onClose={() => setSnack(null)}
        message={snack ?? ''}
      />
    </Box>
  )
}
