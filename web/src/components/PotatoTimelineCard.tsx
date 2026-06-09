import { Box, Card, CardContent, Chip, LinearProgress, Stack, Typography } from '@mui/material'
import type { PotatoPlanting } from '../api/types'
import { fmtDate } from '../format'

export default function PotatoTimelineCard({ planting }: { planting: PotatoPlanting }) {
  const labels = planting.stages.map((s) => s.label)
  const currentIndex = labels.indexOf(planting.current_stage)

  return (
    <Card>
      <CardContent>
        <Stack direction="row" alignItems="center" spacing={1}>
          <Typography variant="subtitle1" fontWeight={600} sx={{ flex: 1 }}>
            {planting.variety}
          </Typography>
          <Chip label={planting.category_display} size="small" />
        </Stack>
        {planting.bed && (
          <Typography variant="body2" color="text.secondary">
            {planting.bed}
          </Typography>
        )}

        <Box sx={{ overflowX: 'auto', mt: 1.5 }}>
          <Stack direction="row" sx={{ minWidth: 'min-content' }}>
            {planting.stages.map((stage, i) => {
              const reached =
                planting.harvested_on != null || (currentIndex >= 0 && i <= currentIndex)
              const isCurrent = stage.label === planting.current_stage
              return (
                <Box key={stage.label} sx={{ width: 92, textAlign: 'center' }}>
                  <Box
                    sx={{
                      width: isCurrent ? 16 : 10,
                      height: isCurrent ? 16 : 10,
                      borderRadius: '50%',
                      mx: 'auto',
                      bgcolor: reached ? 'primary.main' : 'action.disabled',
                    }}
                  />
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
          value={Math.round(planting.progress * 100)}
          sx={{ height: 8, borderRadius: 4, mt: 2 }}
        />
        <Stack direction="row" justifyContent="space-between" sx={{ mt: 1 }}>
          <Typography variant="caption" color="text.secondary">
            Planted {fmtDate(planting.planted_on)}
          </Typography>
          <Typography variant="caption" color="text.secondary">
            {planting.harvested_on
              ? 'Harvested'
              : `Harvest ~ ${fmtDate(planting.estimated_harvest)}`}
          </Typography>
        </Stack>
      </CardContent>
    </Card>
  )
}
