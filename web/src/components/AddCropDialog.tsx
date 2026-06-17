import { useState } from 'react'
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from '@mui/material'
import { useQueryClient } from '@tanstack/react-query'
import { useBeds, useCreateCrop, useCropCatalog, useDeleteCrop, useUpdateCrop } from '../api/hooks'
import { api } from '../api/client'
import type { Crop } from '../api/types'

/** Add a new crop planting, or edit/delete an existing one when `crop` is given. */
export default function AddCropDialog({
  crop: existing,
  onClose,
}: {
  crop?: Crop
  onClose: () => void
}) {
  const editing = existing != null
  const createCrop = useCreateCrop()
  const updateCrop = useUpdateCrop()
  const deleteCrop = useDeleteCrop()
  const catalog = useCropCatalog()
  const beds = useBeds()
  const qc = useQueryClient()
  const todayIso = new Date().toISOString().slice(0, 10)

  const [photo, setPhoto] = useState<File | null>(null)
  const [crop, setCrop] = useState(existing?.crop ?? '')
  const [variety, setVariety] = useState(existing?.variety ?? '')
  const [plantedOn, setPlantedOn] = useState(existing?.planted_on ?? todayIso)
  const [bed, setBed] = useState(existing?.bed ?? '')
  const [quantity, setQuantity] = useState(existing?.quantity != null ? String(existing.quantity) : '')
  const [expectedHarvest, setExpectedHarvest] = useState(existing?.expected_harvest ?? '')
  const [notes, setNotes] = useState(existing?.notes ?? '')
  const [error, setError] = useState<string | null>(null)

  const busy = createCrop.isPending || updateCrop.isPending || deleteCrop.isPending

  // Crop-rotation hint: warn if this crop's botanical family was grown in the
  // chosen bed within roughly the last year. Skipped while editing the same
  // planting (its own history would otherwise flag it).
  const chosen = (catalog.data ?? []).find((c) => c.key === crop)
  const bedKey = bed.trim().toLowerCase()
  const bedHistory = (beds.data ?? []).find((b) => b.bed.trim().toLowerCase() === bedKey)
  const rotationClash =
    chosen?.family &&
    bedKey &&
    bedHistory &&
    !(editing && existing.bed.trim().toLowerCase() === bedKey) &&
    bedHistory.recent_families.includes(chosen.family)
      ? bedHistory
      : null

  const save = async () => {
    if (!crop) {
      setError('Pick a crop.')
      return
    }
    const quantityNum = quantity.trim() ? Number(quantity) : null
    if (quantityNum != null && (!Number.isInteger(quantityNum) || quantityNum < 0)) {
      setError('Quantity must be a whole number.')
      return
    }
    const payload = {
      crop,
      variety: variety.trim(),
      planted_on: plantedOn,
      bed: bed.trim(),
      quantity: quantityNum,
      expected_harvest: expectedHarvest || null,
      notes: notes.trim(),
    }
    try {
      let id = existing?.id
      if (editing) await updateCrop.mutateAsync({ id: existing.id, patch: payload })
      else id = ((await createCrop.mutateAsync(payload)) as Crop).id
      if (photo && id != null) {
        await api.uploadCropPhoto(id, photo)
        qc.invalidateQueries({ queryKey: ['crops'] })
      }
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save.')
    }
  }

  const remove = async () => {
    if (!editing) return
    if (!window.confirm(`Delete ${existing.crop_label}? Its watering and harvest reminders go too.`)) {
      return
    }
    try {
      await deleteCrop.mutateAsync(existing.id)
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to delete.')
    }
  }

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="xs">
      <DialogTitle>{editing ? 'Edit crop' : 'New crop'}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <TextField
            select
            label="Crop"
            value={crop}
            onChange={(e) => setCrop(e.target.value)}
            autoFocus={!editing}
            helperText={catalog.isError ? 'Could not load the crop list' : undefined}
          >
            {(catalog.data ?? []).map((c) => (
              <MenuItem key={c.key} value={c.key}>
                {c.label}
              </MenuItem>
            ))}
          </TextField>
          <TextField
            label="Variety (optional, e.g. Maris Piper)"
            value={variety}
            onChange={(e) => setVariety(e.target.value)}
          />
          <TextField
            label="Planted on"
            type="date"
            value={plantedOn}
            onChange={(e) => setPlantedOn(e.target.value)}
            slotProps={{ inputLabel: { shrink: true } }}
          />
          <TextField label="Bed / row (optional)" value={bed} onChange={(e) => setBed(e.target.value)} />
          {rotationClash && (
            <Alert severity="warning" sx={{ py: 0 }}>
              {chosen?.family_label ?? 'This family'} was grown in {rotationClash.bed} recently (
              {rotationClash.last_crop}). Rotating to a different bed helps avoid soil pests and
              disease.
            </Alert>
          )}
          <TextField
            label="Quantity planted (optional)"
            type="number"
            value={quantity}
            onChange={(e) => setQuantity(e.target.value)}
          />
          <TextField
            label="Expected harvest (optional)"
            type="date"
            value={expectedHarvest}
            onChange={(e) => setExpectedHarvest(e.target.value)}
            slotProps={{ inputLabel: { shrink: true } }}
            helperText="Leave blank to estimate from the crop's usual season."
          />
          <Button component="label" variant="outlined" size="small" sx={{ alignSelf: 'flex-start' }}>
            {photo ? `Photo: ${photo.name}` : existing?.photo ? 'Replace photo' : 'Add photo'}
            <input
              type="file"
              accept="image/*"
              hidden
              onChange={(e) => setPhoto(e.target.files?.[0] ?? null)}
            />
          </Button>
          <TextField
            label="Notes (optional)"
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            multiline
            minRows={2}
          />
          {error && (
            <Typography color="error" variant="body2">
              {error}
            </Typography>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        {editing && (
          <Button color="error" onClick={remove} disabled={busy} sx={{ mr: 'auto' }}>
            Delete
          </Button>
        )}
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={save} disabled={busy}>
          {editing ? 'Save' : 'Add'}
        </Button>
      </DialogActions>
    </Dialog>
  )
}
