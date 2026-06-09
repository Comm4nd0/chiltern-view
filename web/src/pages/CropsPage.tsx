import { useState } from 'react'
import { Box, Fab, Stack, Typography } from '@mui/material'
import AddIcon from '@mui/icons-material/Add'
import { useCrops } from '../api/hooks'
import QueryBoundary from '../components/QueryBoundary'
import CropCard from '../components/CropCard'
import AddCropDialog from '../components/AddCropDialog'

export default function CropsPage() {
  const crops = useCrops('growing')
  const [open, setOpen] = useState(false)

  return (
    <Box>
      <QueryBoundary query={crops}>
        {(list) =>
          list.length === 0 ? (
            <Typography align="center" color="text.secondary" sx={{ mt: 8 }}>
              Nothing growing yet — add a crop.
            </Typography>
          ) : (
            <Stack spacing={1}>
              {list.map((c) => (
                <CropCard key={c.id} crop={c} />
              ))}
            </Stack>
          )
        }
      </QueryBoundary>

      <Fab
        color="primary"
        sx={{ position: 'fixed', bottom: 24, right: 24 }}
        onClick={() => setOpen(true)}
        aria-label="Add crop"
      >
        <AddIcon />
      </Fab>
      {open && <AddCropDialog onClose={() => setOpen(false)} />}
    </Box>
  )
}
