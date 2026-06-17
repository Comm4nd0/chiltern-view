import { useState } from 'react'
import {
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  FormControlLabel,
  MenuItem,
  Stack,
  Switch,
  TextField,
  Typography,
} from '@mui/material'
import { useQueryClient } from '@tanstack/react-query'
import { useCreateAnimal, useUpdateAnimal } from '../api/hooks'
import { api } from '../api/client'
import type { Animal } from '../api/types'
import { SPECIES } from '../animals'

export default function AnimalDialog({
  animal,
  onClose,
}: {
  animal?: Animal
  onClose: () => void
}) {
  const editing = animal != null
  const create = useCreateAnimal()
  const update = useUpdateAnimal()
  const qc = useQueryClient()
  const [name, setName] = useState(animal?.name ?? '')
  const [species, setSpecies] = useState(animal?.species ?? 'chicken')
  const [breed, setBreed] = useState(animal?.breed ?? '')
  const [active, setActive] = useState(animal?.active ?? true)
  const [photo, setPhoto] = useState<File | null>(null)
  const [uploading, setUploading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const busy = create.isPending || update.isPending || uploading

  const save = async () => {
    if (!name.trim()) {
      setError('Enter a name.')
      return
    }
    try {
      let id = animal?.id
      if (editing) {
        await update.mutateAsync({
          id: animal.id,
          patch: { name: name.trim(), species, breed: breed.trim(), active },
        })
      } else {
        const created = await create.mutateAsync({ name: name.trim(), species, breed: breed.trim() })
        id = created.id
      }
      if (photo && id != null) {
        setUploading(true)
        await api.uploadAnimalPhoto(id, photo)
        qc.invalidateQueries({ queryKey: ['animals'] })
        qc.invalidateQueries({ queryKey: ['overview'] })
      }
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save.')
    } finally {
      setUploading(false)
    }
  }

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="xs">
      <DialogTitle>{editing ? 'Edit animal' : 'New animal'}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ mt: 1 }}>
          <TextField
            label="Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            autoFocus
            required
          />
          <TextField
            select
            label="Species"
            value={species}
            onChange={(e) => setSpecies(e.target.value)}
          >
            {SPECIES.map(([value, label]) => (
              <MenuItem key={value} value={value}>
                {label}
              </MenuItem>
            ))}
          </TextField>
          <TextField label="Breed (optional)" value={breed} onChange={(e) => setBreed(e.target.value)} />
          <Button component="label" variant="outlined" size="small" sx={{ alignSelf: 'flex-start' }}>
            {photo ? `Photo: ${photo.name}` : animal?.photo ? 'Replace photo' : 'Add photo'}
            <input
              type="file"
              accept="image/*"
              hidden
              onChange={(e) => setPhoto(e.target.files?.[0] ?? null)}
            />
          </Button>
          {editing && (
            <FormControlLabel
              control={<Switch checked={active} onChange={(e) => setActive(e.target.checked)} />}
              label={active ? 'Active' : 'Retired'}
            />
          )}
          {error && (
            <Typography color="error" variant="body2">
              {error}
            </Typography>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={save} disabled={busy}>
          {editing ? 'Save' : 'Add'}
        </Button>
      </DialogActions>
    </Dialog>
  )
}
