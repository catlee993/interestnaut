import React from "react";
import Box from "@mui/material/Box";
import Skeleton from "@mui/material/Skeleton";

export function LoadingSkeleton() {
  const items = Array.from({ length: 8 });

  return (
    <Box
      display="grid"
      sx={{ gridTemplateColumns: "repeat(auto-fill, minmax(240px, 1fr))" }}
      gap={2}
    >
      {items.map((_, i) => (
        <Box
          key={i}
          display="flex"
          flexDirection="column"
          alignItems="center"
          p={2}
          border="1px solid rgba(0, 0, 0, 0.12)"
          borderRadius={1}
        >
          <Skeleton
            variant="rectangular"
            width={210}
            height={118}
            sx={{ mb: 1 }}
          />
          <Skeleton variant="text" width="80%" />
          <Skeleton variant="text" width="60%" />
          <Skeleton variant="text" width="40%" />
        </Box>
      ))}
    </Box>
  );
}
