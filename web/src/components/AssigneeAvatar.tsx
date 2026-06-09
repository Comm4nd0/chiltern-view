import { Avatar, Tooltip } from '@mui/material'

const palette = ['#00796B', '#3949AB', '#D84315', '#6A1B9A', '#5D4037', '#455A64']

function colorFor(name: string): string {
  let hash = 0
  for (let i = 0; i < name.length; i++) hash = (hash * 31 + name.charCodeAt(i)) | 0
  return palette[Math.abs(hash) % palette.length]
}

function initials(name: string): string {
  return name
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((s) => s[0]!.toUpperCase())
    .join('')
}

export default function AssigneeAvatar({ name, size = 28 }: { name: string; size?: number }) {
  return (
    <Tooltip title={name}>
      <Avatar sx={{ width: size, height: size, bgcolor: colorFor(name), fontSize: size * 0.4 }}>
        {initials(name)}
      </Avatar>
    </Tooltip>
  )
}
