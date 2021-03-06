title: Extending cocos2d CCSprite to Handle Touches
date: 2012-03-04 12:00
summary: I Wanna Touch U, Till We're Stuck Like Glue 
---

### Extending `CCSprite` Makes My Life Easier
While developing a couple of games that I am currently working on I ended up
finding a need to have a `CCSprite` that would trigger a particular selector.
I wanted something lightweight that I could just throw into anything. So I went
about writing a quick subclass of `CCSprite` that at first I thought would be a
bit of a throw away one time use thing. It turned out however to be simple and
reusable and I find myself reusing the class all over the place, enter
`ClickableSprite`.

The concept is dead simple create a subclass of `CCSprite` adhering to
`CCTargetedTouchDelegate`, and give it a couple of properties that will store a
target and selector. Here's the class definition, don't forget to synthesize
those properties though! 

```objective-c
@interface ClickableSprite : CCSprite <CCTargetedTouchDelegate> 
 
@property (nonatomic, assign) id<NSObject> target;
@property (nonatomic) SEL selector;
 
@end
```

### Handling The Touches
In the implementation file we’ll implement a function
(`containsTouchLocation:`) that will test whether or not a touch is contained
by the sprite. This method was lifted from some place or another, I don't
really remember.

```objective-c
- (BOOL)containsTouchLocation:(UITouch *)touch {
    CGPoint p = [self convertTouchToNodeSpaceAR:touch];
    CGSize size = self.contentSize;
    CGRect r = CGRectMake(-size.width*0.5, 
                          -size.height*0.5, 
                          size.width, 
                          size.height);
    return CGRectContainsPoint(r, p);
}
```

Next we want to implement `ccTouchBegan:withEvent` and `ccTouchEnded:withEvent`
such that when a user touches the sprite and then lifts their finger without
moving it off of the sprite it will fire it's selector.

```objective-c
- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event {
    return [self containsTouchLocation:touch];
}

- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event {
    if(![self containsTouchLocation:touch])
        return;
    [self.target performSelector:self.selector withObject:self];
}
```

Finally we will want to add the sprite as a targeted delegate to the
`CCTouchDispatcher` singleton, we'll just do this in the `onEnter`. And of
course we'll want to remove the sprite from the delegate list when it goes away
(otherwise we'll get `EXC_BAD_ACCESS` when the `CCTouchDispatcher` tries to get
at it).

```objective-c
- (void)onEnter {
    [super onEnter];
    [[CCTouchDispatcher sharedDispatcher] addTargetedDelegate:self 
                                                     priority:0 
                                              swallowsTouches:YES];
}
 
- (void)onExit {
    [[CCTouchDispatcher sharedDispatcher] removeDelegate:self];
    [super onExit];
}
```

### Make That Target Bigger So Your Grandma Can Hit it
That's great, it works pretty well, but sometimes you want to be able to press
a sprite that is kind of small, let's just add another property `clickableSize`
and synthesize it.

```objective-c
@property (nonatomic) CGSize clickableSize;
```
Then we can modify our `containsTouchLocation` function to check for this like
so…

```objective-c
- (BOOL)containsTouchLocation:(UITouch *)touch {
    CGPoint p = [self convertTouchToNodeSpaceAR:touch];
    CGSize size = self.contentSize;
    if(!CGSizeEqualToSize(self.clickableSize, CGSizeZero))
        size = self.clickableSize;
    CGRect r = CGRectMake(-size.width*0.5, 
                          -size.height*0.5, 
                          size.width, 
                          size.height);
    return CGRectContainsPoint(r, p);
}
```

### One More Thing
Oh, and one more thing you might like is to be able to set the priority.
`CCTouchDispatcher` will go through all of its delegates in order of priority,
lower being called first. I haven't found that I need to set the priority after
it has been added to the scene so I haven't bothered to implement that
functionality. At any rate we’ll add another property `touchPriority`

```objective-c
@property (nonatomic) int touchPriority;
```
And then simply modify our `onEnter` function

```objective-c
- (void)onEnter {
    [super onEnter];
    [[CCTouchDispatcher sharedDispatcher] addTargetedDelegate:self 
                                                     priority:self.priority
                                              swallowsTouches:YES];
}
```

To use the sprite you initialize it as you would a normal `CCSprite`, set the
relevant properties, and add to a node like any other sprite as well.

```objective-c
ClickableSprite *sprite = [ClickableSprite spriteWithFile:@"myAwesomeSprite.png"];
sprite.target = self;
sprite.selector = @selector(myAwesomeSelector); 
// Or with the sprite as an argument sprite.selector = @selector(myAwesomeSelector:); 
// which would call a function that would look like 
// - (void)myAwesomeSelector:(ClickableSprite *)clickableSprite
sprite.clickableSize = CGSizeMake(100,100);
sprite.touchPriority = 2;
```

Now we have a nice simple class that we can reuse over and over again.
