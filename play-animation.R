library(tidyverse)
library(nflreadr)
library(gganimate)
library(magick)
library(gifski)
library(randomForest)
library(caret)
library(yardstick)
library(party)
library(modelr)
setwd("~/nfl-big-data-bowl-2024")

set.seed(12)


# Applying model to one play

play_example <- track_with_dist %>% 
  filter((club != possessionTeam) | (nflId == ballCarrierId)) %>%
  filter(displayName != 'football') %>%
  filter(gameId == 2022110300 & playId == 168) # change this line to get a different play

playex <- play_example %>%
  mutate(frameOfCatch = play_example$frameId[play_example$event %in% c('pass_outcome_caught')][[1]]) %>% 
  mutate(frameOfTackle = play_example$frameId[play_example$event %in% c('tackle')][[1]]) %>% 
  filter(frameId >= frameOfCatch & frameId <= frameOfTackle) %>%
  mutate(play_made = tackle+assist) %>%
  group_by(gameId, playId, frameId) %>%
  mutate(sBallCarrier = s[nflId == ballCarrierId],
         aBallCarrier = a[nflId == ballCarrierId],
         dirBallCarrier = dir[nflId == ballCarrierId],
         oBallCarrier = o[nflId == ballCarrierId]) %>% 
  filter(club != possessionTeam) %>%
  ungroup()


dtest2 <- xgb.DMatrix(data = as.matrix(playex[, c('distToFootball', 's', 'a', 'sBallCarrier', 'aBallCarrier', 'dir', 'dirBallCarrier', 'o', 'oBallCarrier')]))

live_predictions <- predict(xgb_model, newdata = dtest2)

live_preds <- playex %>%
  mutate(pred_tackle = as.numeric(live_predictions),
         play_made = as.numeric(play_made)) %>% 
  arrange(gameId, playId) %>%
  select(nflId, displayName, gameId, playId, frameId, quarter, down, playDescription, gameDate, week, play_made, pred_tackle, distToFootball, s, a, sBallCarrier, aBallCarrier, x, y)

for_anim <- live_preds %>%
  group_by(gameId, playId, frameId) %>%
  mutate(highest_prob = max(pred_tackle)) %>% 
  ungroup() %>% 
  mutate(likely_tackler = if_else(pred_tackle < highest_prob, 0, 1)) %>%
  select(nflId, displayName, frameId, likely_tackler)


# Play Animation 
one_play = track_with_dist %>% 
  filter(gameId == 2022110300 & playId == 168)  %>% # make sure this line 21
  left_join(for_anim, by = c("nflId", "displayName", 'frameId')) %>% 
  replace_na(list(likely_tackler = 0))

one_play_for_plot = one_play
one_play_for_plot$time = format(one_play_for_plot$time, format = "%Y-%m-%d %H:%M:%OS3")

one_play_for_plot_home =  one_play_for_plot %>% filter(club == 'HOU') 
one_play_for_plot_away =  one_play_for_plot %>% filter(club == 'PHI')
one_play_for_plot_ball =  one_play_for_plot %>% filter(club == 'football') 

# specify where the extra markings should go
x_markings = seq(from = 11, to = 109, by = 1)
x_markings = x_markings[x_markings %% 5 != 0]

y_bottom = rep(1, length(x_markings))
y_lower_mid = rep(18, length(x_markings))
y_upper_mid = rep(53.3-18, length(x_markings))
y_top = rep(53.3 - 1, length(x_markings))

# specify where the numbers should go
numbers_x = seq(from = 20, to = 100, by = 10)
numbers_bottom_y = rep(3, length(numbers_x))
numbers_top_y = rep(53.3-3, length(numbers_x))

# generate the base plot to animate
base_plot = ggplot(one_play_for_plot_ball, aes(x = x, y = y)) +
  xlim(0,120) + ylim(0, 53.3) +
  theme(panel.background = element_rect(fill='darkgreen', colour='red'),
        panel.grid.major = element_blank(),
        panel.grid.minor = element_blank(),
        axis.title = element_blank(),
        axis.text = element_blank(),
        axis.ticks =  element_blank(),
        plot.title = element_text(size = 12)) + 
  geom_hline(yintercept=0, colour = 'white') +
  geom_hline(yintercept=53.3, colour = 'white') +
  geom_vline(xintercept = seq(0, 120, 10), colour = 'white') + 
  geom_rect(aes(xmin = 0.2 , xmax = 9.8, ymin = 0.2, ymax = 53.1) ) + 
  geom_rect(aes(xmin = 110.2 , xmax = 119.8, ymin = 0.2, ymax = 53.1) ) + 
  geom_text(data = data.frame(x = x_markings, y =y_bottom), aes(label = 'l'), color = 'white')+
  geom_text(data = data.frame(x = x_markings, y =y_lower_mid), aes(label = 'l'), colour = 'white') +
  geom_text(data = data.frame(x = x_markings, y =y_upper_mid), aes(label = 'l'), color = 'white') +
  geom_text(data = data.frame(x = x_markings, y =y_top), aes(label = 'l'), color = 'white') + 
  geom_text(data = data.frame(x = 12.5, y = 53.3 / 2.0), aes(label = 'l'), color = 'white', size = 10) + 
  geom_text(data = data.frame(x = 107.5, y = 53.3 / 2.0), aes(label = 'l'), color = 'white', size = 10) + 
  geom_text(data= data.frame(x = numbers_x, y = numbers_bottom_y), aes(label = 50 - abs( 50 - (numbers_x-10) )), colour = 'white', size = 5) +
  geom_text(data= data.frame(x = numbers_x, y = numbers_top_y), aes(label = 50 - abs( 50 - (numbers_x-10) )), colour = 'white', size = 5) +
  geom_point(data = one_play_for_plot_home, aes(x=x,y=y), colour = '#A71930', size = 5) + 
  geom_point(data = one_play_for_plot_away, aes(x=x,y=y), colour = if_else(one_play_for_plot_away$likely_tackler == 1, 'yellow', '#004C54'), size = 5) +
  geom_text(data = one_play_for_plot_home, aes(x = x, y = y, label = jerseyNumber), colour = 'white') +
  #geom_text(data = one_play_for_plot_away, aes(x = x, y = y, label = jerseyNumber), colour = 'white') +
  geom_point(colour = 'white', size = 2)

anim <- base_plot + transition_states(time,
                                      transition_length = 10, state_length = 10)


animate(anim, width = 800, height = 400, fps = 20)

anim_save('gif3.gif', animate(anim, width = 800, height = 400, fps = 20))
