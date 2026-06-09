import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Box,
  Card,
  CardActionArea,
  CardContent,
  Chip,
  Fab,
  IconButton,
  Stack,
  Typography,
} from '@mui/material'
import AddIcon from '@mui/icons-material/Add'
import ArrowBackIcon from '@mui/icons-material/ArrowBack'
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutline'
import { useAnimals, useDeleteAnimal } from '../api/hooks'
import type { Animal } from '../api/types'
import QueryBoundary from '../components/QueryBoundary'
import AnimalDialog from '../components/AnimalDialog'
import { SPECIES_EMOJI, ageLabel } from '../animals'

interface SpeciesGroup {
  code: string
  label: string
  animals: Animal[]
}

function groupBySpecies(animals: Animal[]): SpeciesGroup[] {
  const map = new Map<string, SpeciesGroup>()
  for (const a of animals) {
    const group = map.get(a.species) ?? { code: a.species, label: a.species_display, animals: [] }
    group.animals.push(a)
    map.set(a.species, group)
  }
  return [...map.values()].sort((x, y) => x.label.localeCompare(y.label))
}

function AnimalRow({
  animal,
  onOpen,
  onDelete,
}: {
  animal: Animal
  onOpen: (a: Animal) => void
  onDelete: (a: Animal) => void
}) {
  const facts = [ageLabel(animal.date_of_birth), animal.breed].filter(Boolean).join(' · ')
  return (
    <Card sx={{ mb: 1 }}>
      <Box sx={{ display: 'flex', alignItems: 'center', gap: 1, p: 1.5 }}>
        <Box
          sx={{ flex: 1, minWidth: 0, cursor: 'pointer' }}
          onClick={() => onOpen(animal)}
          role="button"
          aria-label={`Open ${animal.name}`}
        >
          <Typography noWrap>{animal.name}</Typography>
          <Typography variant="caption" color="text.secondary">
            {facts || '—'}
          </Typography>
        </Box>
        <Chip
          size="small"
          label={animal.active ? 'Active' : 'Retired'}
          color={animal.active ? 'success' : 'default'}
          variant={animal.active ? 'filled' : 'outlined'}
        />
        <IconButton aria-label={`Remove ${animal.name}`} onClick={() => onDelete(animal)}>
          <DeleteOutlineIcon />
        </IconButton>
      </Box>
    </Card>
  )
}

export default function AnimalsPage() {
  const animals = useAnimals()
  const del = useDeleteAnimal()
  const navigate = useNavigate()
  const [selected, setSelected] = useState<string | null>(null)
  const [dialogOpen, setDialogOpen] = useState(false)

  const confirmDelete = (a: Animal) => {
    if (window.confirm(`Remove ${a.name}? Their tasks stay but become unassigned.`)) {
      del.mutate(a.id)
    }
  }

  return (
    <Box sx={{ pb: 10 }}>
      <QueryBoundary query={animals}>
        {(list) => {
          if (list.length === 0) {
            return (
              <Typography align="center" color="text.secondary" sx={{ mt: 8 }}>
                No animals yet — add your first.
              </Typography>
            )
          }
          const groups = groupBySpecies(list)

          // Top level: a tile per species kept.
          if (selected === null) {
            return (
              <Box
                sx={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))',
                  gap: 1.5,
                }}
              >
                {groups.map((g) => (
                  <Card key={g.code}>
                    <CardActionArea onClick={() => setSelected(g.code)} sx={{ height: '100%' }}>
                      <CardContent sx={{ textAlign: 'center', py: 2 }}>
                        <Typography sx={{ fontSize: 40, lineHeight: 1 }}>
                          {SPECIES_EMOJI[g.code] ?? '🐾'}
                        </Typography>
                        <Typography variant="subtitle1" sx={{ mt: 1 }}>
                          {g.label}
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                          {g.animals.length} {g.animals.length === 1 ? 'animal' : 'animals'}
                        </Typography>
                      </CardContent>
                    </CardActionArea>
                  </Card>
                ))}
              </Box>
            )
          }

          // Drill-down: the individual animals of the chosen species.
          const group = groups.find((g) => g.code === selected)
          return (
            <Stack spacing={1}>
              <Stack direction="row" alignItems="center" spacing={1}>
                <IconButton onClick={() => setSelected(null)} aria-label="Back to all animals">
                  <ArrowBackIcon />
                </IconButton>
                <Typography variant="h6">{group?.label ?? 'Animals'}</Typography>
              </Stack>
              {!group || group.animals.length === 0 ? (
                <Typography color="text.secondary">None of these left.</Typography>
              ) : (
                group.animals.map((a) => (
                  <AnimalRow
                    key={a.id}
                    animal={a}
                    onOpen={() => navigate(`/animals/${a.id}`)}
                    onDelete={confirmDelete}
                  />
                ))
              )}
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
        onClick={() => setDialogOpen(true)}
        aria-label="Add animal"
      >
        <AddIcon />
      </Fab>
      {dialogOpen && <AnimalDialog onClose={() => setDialogOpen(false)} />}
    </Box>
  )
}
