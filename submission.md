## Introduction

In the modern NFL, there is no shortage of extraordinary athletes. Speed demons like Tyreek Hill, dual-threat phenoms like Lamar Jackson, and YAC monsters like Deebo Samuel have put up historic numbers while changing the geometry of a football field as we know it. This means that tackling has perhaps never been more important, as seemingly any play can turn into a touchdown when someone like  Hill has the ball in his hands. With this in mind, here were the main objectives of my project:

1. Create a model that calculates the probability that a defensive player makes a tackle on a given play.
2. Identify the NFL players who make the most and least tackles over expectation.
3. Create a dynamic live tackling animation that can highlight the most likely tacklers over the course of an entire play.

 
## The Model

I used an eXtreme Gradient Boosted Classifier to model this data. My goal was to ultimately create a `tackle probability` metric, which would indicate the likelihood of a player making a tackle on a play given the variables inputted to the model. The response variable was a binary column called `play_made`, which simply indicates if a player made a tackle OR a tackle assist on a play. 

One quick note: for the model, I filtered the data to only contain the frames where a pass was caught by a receiver. I did so because the model's accuracy was steeply lowered when run plays were also included, likely because defenders are a lot closer together on running plays which confused the model. I'll discuss this flaw further in the conclusion.

I used a 60/40 train/test split for the model with the 9 weeks of tracking data provided and it yielded promising but not perfect results. Overall, the model seems to be really good at predicting who <i> isn't </i> a tackler (about a 97% accuracy rate) but is less accurate when identifying actual tacklers, with about a 67% hit rate. Here's the full confusion matrix between the `play_made` and `likely_tackler` (indicates whether or not the player had the highest tackle probability at the catchpoint) columns:

![conf_matrix](https://raw.githubusercontent.com/pranavrajaram/nfl-bdb-2024/main/visualizations/conf_matrix.png)

<h3> Feature Selection & Importance </h3>

Here are the features used in the model along with how important they were in the tackle probability calculation.
1. **distance to football** - distance the potential tackler is to the football calculated using the distance formula (in yds): $$ \text{distToFootball} = \sqrt{(x_{\text{player}} - x_{\text{football}})^2 + (y_{\text{player}} - y_{\text{football}})^2} $$

2. **player speed** - the speed of the potential tackler when the pass is caught (in yds/sec)
3. **player acceleration** - the acceleration of the potential tackler when the pass is caught (in yds/sec^2)
4. **player direction of motion** - the angle of motion of the potential tackler when the pass is caught (in degrees)
5. **player orientation** - the orientation of the potential tackler when the pass is caught (in degrees)
6. **ballcarier speed** - the speed of the ballcarrier when the pass is caught in (yds/sec)
7. **ballcarrier acceleration** - the acceleration of the ballcarrier when the pass is caught in (yds/sec^2)
8. **ballcarrier direction of motion** - the angle of motion of the ballcarrier when the pass is caught (in degrees)
9. **ballcarrier orientation** - the oritentation of the ballcarier when the pass is caught (in degrees)

![importance](https://raw.githubusercontent.com/pranavrajaram/nfl-bdb-2024/main/visualizations/importance.png)

Understandably, the player's distance to the ball was the most important aspect of the model. This makes intuitive sense as players who are closer to the ball are more likely to make a tackle. We can also see that the player's speed, acceleration, and the ballcarrier's direction of motion played an important role in determining the tackle probabilities.


<h3> Model Evaluation </h3>

<b> Example: </b> 
Here's a play from a Week 9 game between the Eagles and Texans that demonstrates the capabilities of the model.

<img src='https://media.giphy.com/media/v1.Y2lkPTc5MGI3NjExOWRnaG56aDl3ZnVqeTYxbjUwdGE4cHEyOGw0enBuemZlOHdodnNnbSZlcD12MV9pbnRlcm5hbF9naWZfYnlfaWQmY3Q9Zw/W9EepD4TMY07A9RSxJ/giphy-downsized-large.gif'>

When the running back makes the catch out of the backfield, here's what the model predicts will go down:

![playexample.png](https://raw.githubusercontent.com/pranavrajaram/nfl-bdb-2024/main/visualizations/playexample.png)

The model asserts that Maddox (#29, yellow star) has the highest tackle probability at around 62%. However, as seen in the video, Maddox doesn't wrap up and Gardner-Johnson (#23) instead makes the play. So, Gardner-Johnson gets credited with a Tackle Over Expected as he makes the tackle despite not having the highest chance of making the play when the pass is caught.

<b> The Most Improbable Tackle: </b> This is the play that the model determined to be the least likely tackle of the dataset, from the Eagles-Steelers Week 8 game. The tackler, linebacker Alex Highsmith (highlighted in yellow), was given just a 0.036% chance of making the tackle on the play, which makes sense considering how far away he is from DeVonta Smith, the ballcarrier, when the catch is made.

![gif1](https://raw.githubusercontent.com/pranavrajaram/nfl-bdb-2024/main/visualizations/gif2.gif)

<h3> Player Evaluation with Tackle Rate Over Expectation (TROE) </h3>

Now that we know when players were "supposed" to make a tackle, we can use that information to determine the best and worst tacklers compared to expectation. A player has a high Tackle Rate Over Expected if they have more tackles than what the model predicted them to make, and vice versa. The `Tackle Rate` and `Exp. Tackle Rate` columns in the figure below are simply calculated by dividing `Tackles` and `Exp. Tackles` by `Total Plays`, respectively. I did this to even out sample size discrepencies for each player.

![top10](https://raw.githubusercontent.com/pranavrajaram/nfl-bdb-2024/main/visualizations/top10.png)

![bottom10](https://raw.githubusercontent.com/pranavrajaram/nfl-bdb-2024/main/visualizations/bottom10.png)

It makes sense that the majority of the most outstanding tacklers are safeties and linebackers. After all, they usually have the most distance to traverse to make a tackle, meaning the ones they do make are typically impressive. By the same logic, it checks out that most of the worst tacklers are cornerbacks - tackling is not a part of a CB's typical strength profile, but they are still expected to make tackles as they are often very close to the ball carrier.

![corplot](https://raw.githubusercontent.com/pranavrajaram/nfl-bdb-2024/main/visualizations/corplot.png)

In this scatterplot, we can see a broader view of all players and how well they tackle. Players above the dotted red line make more tackles than expected, and players below it make less. The plot also serves as a nice affirmation for the model's accuracy, as there is a rather strong correlation coefficient of 0.888 between predicted tackle rate and actual tackle rate.

<h3> Most Likely Tackler Animation </h3>

Now that I had a model that could determine tackle probabilities at the catchpoint, I wanted to extend it to an entire play. I created a new set of test data, this time including all the frames between the catchpoint and the tackle, and then applied my model to it. This gave me the tackle probabilities for every defensive player over the course of an entire play. Here's the same DeVonta Smith play animation from above, but this time, the highlighted defender is the one with the highest probability at that specific frame:

![gif2](https://raw.githubusercontent.com/pranavrajaram/nfl-bdb-2024/main/visualizations/gif3.gif)

For good measure, here's the live tackler animation of the Eagles-Texans play as well:

![gif3](https://raw.githubusercontent.com/pranavrajaram/nfl-bdb-2024/main/visualizations/gif1.gif)

As expected, once Maddox misses the tackle, Gardner-Johnson becomes the likely tackler and makes the play.

## Conclusion

The model is obviously far from perfect (after all, the basis of the project was that NFL players defy expectations to cause missed tackles), but it still provides valuable information regardling tackle probabilities on passing plays. This could be used in player analysis (to assess the best and worst tacklers) as well as in NFL game broadcasts - similar to how Amazon's PrimeVision telecast identifies players who might be blitzing the quarterback on a play, they could also highlight the most likely tacklers in the open field just like in the likely tackler animation. 

As mentioned above, the primary flaw with the model is that it is not adept at dealing with running plays. It would certainly be possible to create a new model with different features (such as offensive formation, defenders in the box, defensive gap alignment, etc.) that would hopefully be more accurate in assessing tackle probability on runs, but I didn't want to cast too wide of a net for this project and have it be all over the place. It is definitely something to continue investigating so that we can create a cohesive tackle probability metric and expand the live tackler animations to all plays.

All of the code used for the project can be found here: https://github.com/pranavrajaram/nfl-bdb-2024. 

Special thanks to Tej Seth for answering all my questions, and shoutout to Michael Lopez, Thompson Bliss, and the rest of the team who set the BDB up every year.
