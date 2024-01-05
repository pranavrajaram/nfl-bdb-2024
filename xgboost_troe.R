library(tidyverse)
library(nflreadr)
library(gganimate)
library(magick)
library(gifski)
library(randomForest)
library(caret)
library(yardstick)
library(party)
library(partykit)
library(xgboost)
library(ggthemes)
library(gt)
library(gtExtras)
library(ggrepel)
setwd("~/nfl-big-data-bowl-2024")

set.seed(12) # GOAT


track_1 <- read_csv('tracking_week_1.csv')

track_2 <- read_csv('tracking_week_2.csv')

track_3 <- read_csv('tracking_week_3.csv')

track_4 <- read_csv('tracking_week_4.csv')

track_5 <- read_csv('tracking_week_5.csv')

track_6 <- read_csv('tracking_week_6.csv')

track_7 <- read_csv('tracking_week_7.csv')

track_8 <- read_csv('tracking_week_8.csv')

track_9 <- read_csv('tracking_week_9.csv')

all_track <- bind_rows(track_1, track_2, track_3, track_4, track_5, track_6, track_7, track_8, track_9) # all tracking data

games <- read_csv('games.csv')

plays <- read_csv('plays.csv')

players <- read_csv('players.csv')

tackles <- read_csv('tackles.csv') %>%
  replace_na(list(tackle = 0, assist = 0, forcedFumble = 0, pff_missedTackle = 0))

merged_track_1 <- all_track %>% left_join(inner_join(games, plays, by = c('gameId')), by = c("gameId", 'playId')) %>% left_join(tackles, by = c('gameId', 'playId', 'nflId'))

# Add player distances to football
track_with_dist <- merged_track_1 %>%
  group_by(gameId, playId, frameId) %>% 
  mutate(footballInPlay = sum(displayName == "football") > 0) %>% 
  filter(footballInPlay) %>%
  mutate(xFootball = x[displayName == "football"],
         yFootball = y[displayName == "football"]) %>% 
  ungroup() %>%
  group_by(gameId, playId) %>%
  mutate(distToFootball = sqrt((x - xFootball) ^ 2 + (y - yFootball) ^ 2)) %>%
  mutate(distToFootball= as.numeric(distToFootball)) %>%
  replace_na(list(tackle = 0, assist = 0, forcedFumble = 0, pff_missedTackle = 0)) %>%
  ungroup()


# Filter data to catchpoint
defense_dist_at_catch <- track_with_dist %>%
  filter((club != possessionTeam) | (nflId == ballCarrierId)) %>%
  filter(displayName != 'football') %>%
  filter(event == 'pass_outcome_caught') %>%
  mutate(play_made = tackle+assist) %>%
  group_by(gameId, playId, frameId) %>%
  mutate(sBallCarrier = s[nflId == ballCarrierId],
         aBallCarrier = a[nflId == ballCarrierId],
         dirBallCarrier = dir[nflId == ballCarrierId],
         oBallCarrier = o[nflId == ballCarrierId]) %>% 
  filter(club != possessionTeam) %>%
  ungroup()


# Building the model
train_indices <- sample(1:nrow(defense_dist_at_catch), 0.6 * nrow(defense_dist_at_catch))
train_data <- defense_dist_at_catch[train_indices, ]
test_data <- defense_dist_at_catch[-train_indices, ]


dtrain <- xgb.DMatrix(data = as.matrix(train_data[, c('distToFootball', 's', 'a', 'sBallCarrier', 'aBallCarrier', 'dir', 'dirBallCarrier', 'o', 'oBallCarrier')]), label = train_data$play_made)

params <- list(objective = "binary:logistic", max_depth = 6, eta = 0.3, nthread = 2)

xgb_model <- xgboost(data = dtrain, params = params, nrounds = 100)

importance <-  xgb.importance(colnames(dtrain), model = xgb_model)

dtest <- xgb.DMatrix(data = as.matrix(defense_dist_at_catch[, c('distToFootball', 's', 'a', 'sBallCarrier', 'aBallCarrier', 'dir', 'dirBallCarrier', 'o', 'oBallCarrier')]))

predictions <- predict(xgb_model, newdata = dtest)


# Apply predictions to data
data_with_preds <- defense_dist_at_catch %>%
  mutate(pred_tackle = as.numeric(predictions),
         play_made = as.numeric(play_made)) %>% arrange(distToFootball) %>%
  arrange(gameId, playId) %>%
  select(nflId, displayName, gameId, playId, quarter, down, playDescription, gameDate, week, play_made, pred_tackle, distToFootball, s, a, sBallCarrier, aBallCarrier)


# Identify player with highest tackle probability on each play
full_stats <- data_with_preds %>%
  group_by(gameId, playId) %>%
  mutate(highest_prob = max(pred_tackle)) %>% 
  ungroup() %>% 
  mutate(likely_tackler = if_else(pred_tackle < highest_prob, 0, 1)) %>% 
  select(-highest_prob) %>%
  mutate(likely_tackler = as.factor(likely_tackler),
         play_made = as.factor(play_made))

conf_matrix <- confusionMatrix(full_stats$likely_tackler, full_stats$play_made)

tcl <- nflfastR::teams_colors_logos %>%
  select(team_abbr, team_color, team_color2)

rosters <- nflreadr::load_rosters() %>%
  select(gsis_it_id, position, headshot_url, team)

# Calculate TROE
oe <- full_stats %>%
  mutate(likely_tackler = as.numeric(likely_tackler)-1,
         play_made = as.numeric(play_made)-1) %>%
  group_by(nflId) %>%
  summarise(name = first(displayName),
            plays_made = sum(play_made),
            exp_plays_made = sum(likely_tackler),
            plays = n(),
            tackle_rate = plays_made/plays,
            exp_tackle_rate = exp_plays_made/plays,
            troe = tackle_rate - exp_tackle_rate) %>%
  mutate(plays_oe = plays_made - exp_plays_made) %>%
  filter(plays_made != 0 & exp_plays_made != 0) %>%
  ungroup() %>%
  filter(plays >= 75) %>%
  mutate(nflId = as.character(nflId),
         tackle_rate = round(tackle_rate, 3),
         exp_tackle_rate = round(exp_tackle_rate, 3),
         troe = round(troe, 3)) %>%
  left_join(rosters, by = c('nflId' =  'gsis_it_id')) %>%
  left_join(tcl, by = c('team' = 'team_abbr'))
