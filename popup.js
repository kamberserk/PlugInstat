// Wait for DOM to be fully loaded
document.addEventListener('DOMContentLoaded', function() {
    // YouTube link functionality
    const youtubeButton = document.getElementById('youtubeLink');
    if (youtubeButton) {
        youtubeButton.addEventListener('click', function() {
            chrome.tabs.create({url: 'https://youtube.com/@coach_mert?sub_confirmation=1'});
        });
    }
}); 