//surveyJS object options, can be customized for a specific questionnaire by id
export default {
    "default": {
        showQuestionNumbers: 'off',
        completeText: 'Submit',
        clearInvisibleValues: 'onHidden',
        requiredText: '',
        completedHtml: '<h3>The screening is complete.</h3><h3>You may now close the window.</h3>'
    },
    "WHOAUDIT": {
        title: "Alcohol Screening",
        logo: "favicon.png",
        logoWidth: 70,
        logoHeight: 60
    },
    "MINICOG": {
        focusFirstQuestionAutomatic: true,
        surveyValidateQuestion: function(survey, options) {
            const QUESTION1_ID = 'minicog-question1';
            const QUESTION2_ID = 'minicog-question2';
            const wordRecallVal = parseInt(options.data[QUESTION1_ID]);
            const clockDrawVal = parseInt(options.data[QUESTION2_ID]);
            if (wordRecallVal > 3 || wordRecallVal < 0) {
                options.errors[QUESTION1_ID] = 'The value must be between 0 and 3.';
            }
            
            if (clockDrawVal < 0 ||  clockDrawVal > 2 || clockDrawVal === 1) {
                options.errors[QUESTION2_ID] = 'The value must be 0 or 2.';
            }
            // tell survey that we are done with the server validation
            options.complete();
        }
    }
};
