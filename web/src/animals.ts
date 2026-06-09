/** Species choices + display helpers shared by the animal pages and dialogs. */

export const SPECIES: [string, string][] = [
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

export const SPECIES_EMOJI: Record<string, string> = {
  chicken: '🐔',
  duck: '🦆',
  goose: '🦢',
  turkey: '🦃',
  goat: '🐐',
  sheep: '🐑',
  pig: '🐷',
  cow: '🐄',
  horse: '🐴',
  rabbit: '🐰',
  tortoise: '🐢',
  dog: '🐕',
  cat: '🐈',
  bees: '🐝',
  other: '🐾',
}

/** Age from date of birth, e.g. "2 yr 3 mo" / "5 mo". Null if unknown. */
export function ageLabel(dob: string | null): string | null {
  if (!dob) return null
  const birth = new Date(dob)
  if (Number.isNaN(birth.getTime())) return null
  const now = new Date()
  let months = (now.getFullYear() - birth.getFullYear()) * 12 + (now.getMonth() - birth.getMonth())
  if (now.getDate() < birth.getDate()) months -= 1
  if (months < 0) return null
  const years = Math.floor(months / 12)
  const rem = months % 12
  if (years === 0) return `${months} mo`
  if (rem === 0) return `${years} yr`
  return `${years} yr ${rem} mo`
}
