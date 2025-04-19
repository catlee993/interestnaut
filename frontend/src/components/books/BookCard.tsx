import {
  Card,
  CardMedia,
  Typography,
  IconButton,
  Box,
  Chip,
  Tooltip,
  styled,
  Stack,
} from "@mui/material";
import {
  Favorite,
  FavoriteBorder,
  MenuBook,
  PlaylistAdd,
  PlaylistAddCheck,
} from "@mui/icons-material";
import { FeedbackControls } from "../common/FeedbackControls";

interface BookWithSavedStatus {
  title: string;
  author: string;
  key: string;
  cover_path: string;
  year?: number;
  subjects?: string[];
}

interface BookCardProps {
  book: BookWithSavedStatus;
  isSaved: boolean;
  isInReadList?: boolean;
  view: "default" | "readlist";
  onSave: (title: string, author: string) => void;
  onAddToReadList?: (title: string, author: string) => void;
  onRemoveFromReadList?: (title: string, author: string) => void;
  onLike?: (title: string, author: string) => void;
  onDislike?: (title: string, author: string) => void;
}

interface LibraryControlsProps {
  isInLibrary: boolean;
  onToggleLibrary: () => void;
}

interface ReadListControlsProps {
  isInReadList: boolean;
  onAddToReadList: () => void;
}

const StyledCard = styled(Card)(({ theme }) => ({
  height: "100%",
  width: "100%",
  position: "relative",
  overflow: "hidden",
  backgroundColor: "var(--surface-color)",
  transition: "transform 0.2s ease-in-out, box-shadow 0.2s ease-in-out",
  border: "2px solid rgba(123, 104, 238, 0.3)",
  "&:hover": {
    transform: "translateY(-4px)",
    boxShadow: "0 10px 20px rgba(0,0,0,0.2)",
    borderColor: "rgba(123, 104, 238, 0.5)",
  },
}));

const Overlay = styled(Box)(({ theme }) => ({
  position: "absolute",
  bottom: 0,
  left: 0,
  right: 0,
  background:
    "linear-gradient(to top, rgba(0,0,0,1) 0%, rgba(0,0,0,0.95) 20%, rgba(0,0,0,0.85) 40%, rgba(0,0,0,0.6) 70%, rgba(0,0,0,0.3) 85%, transparent 100%)",
  padding: theme.spacing(2),
  color: theme.palette.common.white,
  height: "120px",
}));

const LibraryControls = ({
  isInLibrary,
  onToggleLibrary,
}: LibraryControlsProps) => (
  <IconButton onClick={onToggleLibrary} size="small" sx={{ color: "white" }}>
    {isInLibrary ? (
      <Favorite sx={{ color: "var(--primary-color)" }} />
    ) : (
      <FavoriteBorder />
    )}
  </IconButton>
);

const ReadListControls = ({
  isInReadList,
  onAddToReadList,
}: ReadListControlsProps) => (
  <IconButton onClick={onAddToReadList} size="small" sx={{ color: "white" }}>
    {isInReadList ? (
      <PlaylistAddCheck sx={{ color: "#64b5f6" }} />
    ) : (
      <PlaylistAdd />
    )}
  </IconButton>
);

export function BookCard({
  book,
  isSaved,
  isInReadList = false,
  view = "default",
  onSave,
  onAddToReadList,
  onRemoveFromReadList,
  onLike,
  onDislike,
}: BookCardProps) {
  const hasCover = book.cover_path && book.cover_path !== "";

  return (
    <StyledCard>
      <Box sx={{ position: "relative", width: "100%", paddingTop: "150%" }}>
        {hasCover ? (
          <CardMedia
            component="img"
            image={book.cover_path}
            alt={book.title}
            sx={{
              position: "absolute",
              top: 0,
              left: 0,
              width: "100%",
              height: "100%",
              objectFit: "cover",
            }}
          />
        ) : (
          <Box
            sx={{
              position: "absolute",
              top: 0,
              left: 0,
              width: "100%",
              height: "100%",
              display: "flex",
              flexDirection: "column",
              justifyContent: "center",
              alignItems: "center",
              bgcolor: "rgba(123, 104, 238, 0.1)",
              color: "white",
            }}
          >
            <MenuBook sx={{ fontSize: 60, opacity: 0.7, mb: 2 }} />
            <Typography variant="subtitle1" align="center" sx={{ px: 2 }}>
              {book.title}
            </Typography>
          </Box>
        )}

        <Overlay>
          <Box
            sx={{ position: "absolute", bottom: "58px", left: 16, right: 16 }}
          >
            <Typography variant="h6" component="h2" noWrap>
              {book.title}
            </Typography>
          </Box>

          <Box
            sx={{ position: "absolute", bottom: "36px", left: 16, right: 16 }}
          >
            <Typography variant="body2" noWrap>
              {book.author}
            </Typography>
          </Box>

          <Box
            sx={{
              position: "absolute",
              bottom: 8,
              left: 16,
              right: 16,
              display: "flex",
              justifyContent: "space-between",
              alignItems: "center",
              width: "calc(100% - 32px)",
            }}
          >
            <Box sx={{ display: "flex", alignItems: "center" }}>
              {book.year && (
                <Typography variant="body2" sx={{ opacity: 0.8, mr: 1 }}>
                  {book.year}
                </Typography>
              )}
              {book.subjects && book.subjects.length > 0 && (
                <Tooltip title={book.subjects.join(", ")}>
                  <Chip
                    label={book.subjects[0]}
                    size="small"
                    sx={{
                      bgcolor: "#3c36f4",
                      color: "white",
                      height: "20px",
                      "& .MuiChip-label": { px: 1 },
                    }}
                  />
                </Tooltip>
              )}
            </Box>

            {view === "default" ? (
              <Box sx={{ display: "flex", gap: 1 }}>
                {onAddToReadList && (
                  <ReadListControls
                    isInReadList={isInReadList ?? false}
                    onAddToReadList={() =>
                      onAddToReadList!(book.title, book.author)
                    }
                  />
                )}
                <LibraryControls
                  isInLibrary={isSaved}
                  onToggleLibrary={() => onSave(book.title, book.author)}
                />
              </Box>
            ) : (
              <FeedbackControls
                onLike={() => onLike && onLike(book.title, book.author)}
                onDislike={() =>
                  onDislike && onDislike(book.title, book.author)
                }
                onAddToFavorites={() => onSave(book.title, book.author)}
                isSaved={isSaved}
              />
            )}
          </Box>
        </Overlay>
      </Box>
    </StyledCard>
  );
}
