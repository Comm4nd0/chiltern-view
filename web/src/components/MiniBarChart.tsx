import { Box, useTheme } from '@mui/material'

export interface BarPoint {
  date: string
  count: number
}

/** A lightweight inline-SVG bar chart — no chart library, mirrors the Flutter
 * CustomPainter version. Bars scale to the tallest value; today is highlighted. */
export default function MiniBarChart({
  data,
  height = 72,
}: {
  data: BarPoint[]
  height?: number
}) {
  const theme = useTheme()
  if (data.length === 0) return null
  const max = Math.max(1, ...data.map((d) => d.count))
  const width = 100
  const gap = data.length > 1 ? 1.2 : 0
  const barW = (width - gap * (data.length - 1)) / data.length
  const todayIso = new Date().toISOString().slice(0, 10)

  return (
    <Box sx={{ width: '100%' }}>
      <svg
        viewBox={`0 0 ${width} ${height}`}
        preserveAspectRatio="none"
        width="100%"
        height={height}
        role="img"
        aria-label="Egg laying trend"
      >
        {data.map((d, i) => {
          const h = (d.count / max) * (height - 2)
          const x = i * (barW + gap)
          const isToday = d.date === todayIso
          return (
            <rect
              key={d.date}
              x={x}
              y={height - h}
              width={barW}
              height={Math.max(h, d.count > 0 ? 1 : 0.4)}
              rx={0.6}
              fill={isToday ? theme.palette.primary.main : theme.palette.primary.light}
              opacity={d.count > 0 ? 1 : 0.35}
            />
          )
        })}
      </svg>
    </Box>
  )
}
