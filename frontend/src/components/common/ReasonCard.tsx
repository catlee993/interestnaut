import { Box, Typography, Paper } from "@mui/material";
import { styled } from "@mui/material/styles";
import { FaRobot } from "react-icons/fa";

const StyledPaper = styled(Paper)(({ theme }) => ({
  padding: theme.spacing(2),
  backgroundColor: theme.palette.background.paper,
  borderRadius: theme.shape.borderRadius,
  boxShadow: theme.shadows[1],
}));

interface ReasonCardProps {
  reason: string;
}

export const ReasonCard: React.FC<ReasonCardProps> = ({ reason }) => {
  return (
    <StyledPaper>
      <Box
        sx={{
          display: "flex",
          alignItems: "flex-end",
          justifyContent: "center",
          gap: 1,
          mb: 1,
          pb: 1,
          borderBottom: "1px solid rgba(123, 104, 238, 0.2)",
        }}
      >
        <FaRobot style={{ color: "rgba(140, 134, 258, 0.7)" }} />
        <Typography
          variant="subtitle2"
          sx={{
            color: "rgba(140, 134, 258, 0.7)",
            fontWeight: 500,
            lineHeight: 1,
          }}
        >
          Reasoning behind suggestion
        </Typography>
      </Box>
      <Typography
        variant="body2"
        color="text.secondary"
        sx={{
          textAlign: "center",
          fontStyle: "italic",
          opacity: 0.8,
        }}
      >
        {reason}
      </Typography>
    </StyledPaper>
  );
};
