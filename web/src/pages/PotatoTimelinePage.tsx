import { useState } from 'react'
import { Box, Fab, Stack, Typography } from '@mui/material'
import AddIcon from '@mui/icons-material/Add'
import { usePotatoTimeline } from '../api/hooks'
import QueryBoundary from '../components/QueryBoundary'
import PotatoTimelineCard from '../components/PotatoTimelineCard'
import AddPlantingDialog from '../components/AddPlantingDialog'

export default function PotatoTimelinePage() {
  const timeline = usePotatoTimeline('growing')
  const [open, setOpen] = useState(false)

  return (
    <Box>
      <QueryBoundary query={timeline}>
        {(plantings) =>
          plantings.length === 0 ? (
            <Typography align="center" color="text.secondary" sx={{ mt: 8 }}>
              No potatoes in the ground yet.
            </Typography>
          ) : (
            <Stack spacing={1}>
              {plantings.map((p) => (
                <PotatoTimelineCard key={p.id} planting={p} />
              ))}
            </Stack>
          )
        }
      </QueryBoundary>

      <Fab
        color="primary"
        sx={{ position: 'fixed', bottom: 24, right: 24 }}
        onClick={() => setOpen(true)}
        aria-label="Add planting"
      >
        <AddIcon />
      </Fab>
      {open && <AddPlantingDialog onClose={() => setOpen(false)} />}
    </Box>
  )
}
