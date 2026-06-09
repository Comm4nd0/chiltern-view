import { Box, Button, Card, CardContent, Chip, LinearProgress, Stack, Typography } from '@mui/material'
import { Plant, CheckCircle, Circle, Basket } from '@phosphor-icons/react'
import type { Crop } from '../api/types'
import { fmtDate } from '../format'

export default function CropCard({
  crop,
  onEdit,
  onHarvest,
}: {
  crop: Crop
  onEdit?: () => void
  onHarvest?: () => void
}) {
  const labels = crop.stages.map((s) => s.label)
  const currentIndex = labels.indexOf(crop.current_stage)

  return (
    <Card>
      <CardContent
        sx={{ cursor: onEdit ? 'pointer' : 'default' }}
        onClick={onEdit}
        role={onEdit ? 'button' : undefined}
        aria-label={onEdit ? `Edit ${crop.crop_label}` : undefined}
      >
        <Stack direction="row" alignItems="center" spacing={1}>
          <Plant size={18} weight="fill" color="#34C759" />
          <Typography variant="subtitle1" fontWeight={600} sx={{ flex: 1 }}>
            {crop.crop_label}
          </Typography>
          {crop.variety && <Chip label={crop.variety} size="small" />}
          {crop.harvested_on && crop.yield_kg != null && (
            <Chip label={`${Number(crop.yield_kg)} kg`} size="small" color="success" />
          )}
          {!crop.harvested_on && onHarvest && (
            <Button
              size="small"
              variant="outlined"
              startIcon={<Basket size={16} />}
              onClick={(e) => {
                e.stopPropagation()
                onHarvest()
              }}
            >
              Harvest
            </Button>
          )}
        </Stack>
        {crop.bed && (
          <Typography variant="body2" color="text.secondary">
            {crop.bed}
          </Typography>
        )}

        <Box sx={{ overflowX: 'auto', mt: 1.5 }}>
          <Stack direction="row" sx={{ minWidth: 'min-content' }}>
            {crop.stages.map((stage, i) => {
              const reached = crop.harvested_on != null || (currentIndex >= 0 && i <= currentIndex)
              const isCurrent = stage.label === crop.current_stage
              const color = reached ? '#00796B' : 'rgba(60,60,67,0.25)'
              return (
                <Box key={stage.label} sx={{ width: 92, textAlign: 'center' }}>
                  <Box sx={{ height: 20, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    {isCurrent ? (
                      <CheckCircle size={18} weight="fill" color={color} />
                    ) : (
                      <Circle size={12} weight={reached ? 'fill' : 'regular'} color={color} />
                    )}
                  </Box>
                  <Typography variant="caption" display="block" fontWeight={isCurrent ? 700 : 400}>
                    {stage.label}
                  </Typography>
                  <Typography variant="caption" color="text.secondary">
                    {fmtDate(stage.date)}
                  </Typography>
                </Box>
              )
            })}
          </Stack>
        </Box>

        <LinearProgress
          variant="determinate"
          value={Math.round(crop.progress * 100)}
          sx={{ height: 8, borderRadius: 4, mt: 2 }}
        />
        <Stack direction="row" justifyContent="space-between" sx={{ mt: 1 }}>
          <Typography variant="caption" color="text.secondary">
            Planted {fmtDate(crop.planted_on)}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            {crop.harvested_on
              ? `Harvested ${fmtDate(crop.harvested_on)}`
              : `Harvest ~ ${fmtDate(crop.estimated_harvest)}`}
          </Typography>
        </Stack>
      </CardContent>
    </Card>
  )
}
