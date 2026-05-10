const fs = require('fs');
const path = require('path');

const newNames = [
    'simple-avocado-toast.jpg', 'overnight-oats-with-chia.jpg', 'mediterranean-chickpea-bowl.jpg',
    'ginger-turmeric-lentil-soup.jpg', 'thai-style-tofu-lettuce-cups.jpg', 'cashew-alfredo-with-broccoli.jpg',
    'smoky-bbq-jackfruit-sliders.jpg', 'wild-mushroom-herb-risotto.jpg', 'coconut-vegetable-curry.jpg',
    'chocolate-avocado-pudding.jpg', 'baked-lemon-herb-salmon.jpg', 'sheet-pan-mediterranean-vegetables.jpg',
    'corn-tortilla-chicken-tacos.jpg', 'quinoa-tabbouleh-salad.jpg', 'flourless-chocolate-almond-cake.jpg',
    'garlic-butter-shrimp-with-zoodles.jpg', 'herb-crusted-pork-tenderloin.jpg', 'thai-beef-lettuce-wraps.jpg',
    'creamy-polenta-with-ratatouille.jpg', 'crispy-parmesan-potato-wedges.jpg', 'xylitol-free-peanut-butter-pumpkin-bites.jpg',
    'plain-chicken-and-rice-pup-bowl.jpg', 'carrot-and-apple-horse-cookies.jpg', 'frozen-yogurt-blueberry-drops.jpg',
    'sweet-potato-chews.jpg', 'tuna-cat-crumbles.jpg', 'banana-oat-dog-biscuits.jpg', 'egg-and-spinach-mash.jpg',
    'salmon-skin-cracklings.jpg', 'rice-flour-baby-biscuits.jpg', 'summer-peach-caprese-skewers.jpg',
    'berry-citrus-salad-with-mint.jpg', 'grilled-pineapple-with-cinnamon.jpg', 'apple-cheddar-walnut-salad.jpg',
    'mango-sticky-rice.jpg', 'fig-and-ricotta-toast.jpg', 'watermelon-feta-mint-salad.jpg', 'baked-cinnamon-pears.jpg',
    'tropical-smoothie-parfait.jpg', 'cherry-compote-over-yogurt.jpg', 'roasted-brussels-sprouts-with-bacon.jpg',
    'classic-minestrone.jpg', 'garlic-green-beans-almondine.jpg', 'stuffed-portobello-mushrooms.jpg',
    'creamy-cauliflower-soup.jpg', 'asian-stir-fried-mixed-vegetables.jpg', 'caprese-salad-stack.jpg',
    'charred-corn-esquites.jpg', 'roasted-beet-and-goat-cheese-salad.jpg', 'eggplant-parmesan-bake.jpg'
];

const dir = path.join(__dirname, 'seedImage');
const files = fs.readdirSync(dir).filter(f => f.match(/\.(jpg|jpeg|png|webp)$/i));

// Rename up to 50 files
let count = 0;
for (let i = 0; i < files.length && count < newNames.length; i++) {
    const oldPath = path.join(dir, files[i]);
    const newPath = path.join(dir, newNames[count]);
    
    // Check if it's already named correctly
    if (newNames.includes(files[i])) {
        continue; // Already renamed
    }

    fs.renameSync(oldPath, newPath);
    console.log(`Renamed ${files[i]} to ${newNames[count]}`);
    count++;
}
console.log(`Renamed ${count} files.`);
