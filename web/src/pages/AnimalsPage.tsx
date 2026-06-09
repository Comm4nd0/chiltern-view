import { useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import {
  Box,
  Button,
  Card,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Fab,
  IconButton,
  List,
  ListItem,
  ListItemText,
  MenuItem,
  Stack,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material'
import AddIcon from '@mui/icons-material/Add'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import { useAnimals, useCreateAnimal, useDeleteAnimal } from '../api/hooks'
import QueryBoundary from '../components/QueryBoundary'
import EggLogPage from './EggLogPage'

const SPECIES: [string, string][] = [
  ['chicken', 'Chicken'],
  ['duck', 'Duck'],
  ['goose', 'Goose'],
  ['turkey', 'Turkey'],
  ['goat', 'Goat'],
  ['sheep', 'Sheep'],
  ['pig', 'Pig'],
  ['cow', 'Cow'],
  ['horse', 'Horse'],
  ['rabbit', 'Rabbit'],
  ['tortoise', 'Tortoise'],
  ['dog', 'Dog'],
  ['cat', 'Cat'],
  ['bees', 'Bee colony'],
  ['other', 'Other'],
]

function AddAnimalDialog({ onClose }: { onClose: () => void }) {
  const create = useCreateAnimal()
  const [name, setName] = useState('')
  const [species, setSpecies] = useState('chicken')
  const [breed, setBreed] = useState('')
  const [error, setError] = useState<string | null>(null)

  const save = async () => {
    if (!name.trim()) {
      setError('Enter a name.')
      return
    }
    try {
      await create.mutateAsync({ name: name.trim(), species, breed: breed.trim() })
      onClose()
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to save.')
    }
  }

  return (
    <Dialog open onClose={onClose} fullWidth maxWidth="xs">
      <DialogTitle>New animal</DialogTitle>
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
          {error && (
            <Typography color="error" variant="body2">
              {error}
            </Typography>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={save} disabled={create.isPending}>
          Add
        </Button>
      </DialogActions>
    </Dialog>
  )
}

function AnimalsList() {
  const animals = useAnimals()
  const del = useDeleteAnimal()
  const [dialogOpen, setDialogOpen] = useState(false)

  return (
    <Box>
      <QueryBoundary query={animals}>
        {(list) =>
          list.length === 0 ? (
            <Typography align="center" color="text.secondary" sx={{ mt: 8 }}>
              No animals yet — add your first.
            </Typography>
          ) : (
            <List>
              {list.map((animal) => (
                <Card key={animal.id} sx={{ mb: 1 }}>
                  <ListItem
                    secondaryAction={
                      <IconButton
                        edge="end"
                        aria-label="Remove"
                        onClick={() => {
                          if (
                            window.confirm(
                              `Remove ${animal.name}? Their tasks stay but become unassigned.`,
                            )
                          ) {
                            del.mutate(animal.id)
                          }
                        }}
                      >
                        <DeleteOutlineIcon />
                      </IconButton>
                    }
                  >
                    <ListItemText
                      primary={animal.name}
                      secondary={[animal.species_display, animal.breed].filter(Boolean).join(' · ')}
                    />
                  </ListItem>
                </Card>
              ))}
            </List>
          )
        }
      </QueryBoundary>

      <Fab
        color="primary"
        sx={{ position: 'fixed', bottom: 24, right: 24 }}
        onClick={() => setDialogOpen(true)}
        aria-label="Add animal"
      >
        <AddIcon />
      </Fab>
      {dialogOpen && <AddAnimalDialog onClose={() => setDialogOpen(false)} />}
    </Box>
  )
}

export default function AnimalsPage() {
  const [params, setParams] = useSearchParams()
  const view = params.get('view') === 'eggs' ? 'eggs' : 'animals'

  return (
    <Box>
      <ToggleButtonGroup
        value={view}
        exclusive
        fullWidth
        size="small"
        sx={{ mb: 2 }}
        onChange={(_, v) => {
          if (v) setParams(v === 'eggs' ? { view: 'eggs' } : {})
        }}
      >
        <ToggleButton value="animals">Animals</ToggleButton>
        <ToggleButton value="eggs">Eggs</ToggleButton>
      </ToggleButtonGroup>
      {view === 'eggs' ? <EggLogPage /> : <AnimalsList />}
    </Box>
  )
}
